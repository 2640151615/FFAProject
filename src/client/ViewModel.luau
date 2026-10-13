-- 第一人称视图模型：**共享手臂骨架 + 每把武器接在右手上**。
--
-- 骨架（`ViewModel_Arms`）只克隆一次，换枪只换接在 `RightHand` 上的那个部件。
-- 枪是 Motor6D 的孩子，所以以后播动画时手和枪会一起动——
-- 这正是用关节而不是"各自 CFrame 到相机"的理由。
--
-- 每帧**只设根节点的 CFrame**，其余部件由关节跟随。
-- 手臂的持枪静止姿态已经烘焙在骨架的关节里，实时代码不碰它，动画才有干净的基准。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local ViewModel = {}

local player = Players.LocalPlayer

local ARMS_NAME = "ViewModel_Arms"

-- 骨架根相对相机的静止位姿。手臂是在模型空间里摆好持枪姿态的，
-- 所以根节点放在相机原点上即可——但模型空间是按"看得清结构"建的，
-- 贴到相机上时通常还要整体前推/下压一点，否则会糊在镜头上。
local RIG_POSE = CFrame.new(0, -0.18, -0.42)

-- 整套骨架的统一缩放。
--
-- 骨架是**按一个便于阅读的尺寸建的**（部件 0.3 出头），直接怼到相机前会显得巨大。
-- 与其回头改每个关节坐标，不如在这里统一缩放：部件尺寸和每个 Motor6D 的
-- C0/C1 位置一起乘这个系数，旋转保持不变。这样"骨架长什么样"和
-- "它在屏幕上多大"是两个独立的旋钮。
local RIG_SCALE = 0.75

local arms = nil
local weaponPart = nil
local weaponJoint = nil
local currentWeapon = nil

-- 把自己的肤色套到手臂上。
-- R6 没有独立的手部件，所以手用上臂的颜色。
-- 视图模型是客户端私有的、不参与命中判定，所以这里套皮肤没有任何公平问题。
local function applySkin()
	if not arms or not arms.Parent then
		return
	end

	local character = player.Character
	local bodyColors = character and character:FindFirstChild("Body Colors")
	if not bodyColors then
		return
	end

	local mapping = {
		RightUpperArm = bodyColors.RightArmColor3,
		RightForearm = bodyColors.RightArmColor3,
		RightHand = bodyColors.RightArmColor3,
		LeftUpperArm = bodyColors.LeftArmColor3,
		LeftForearm = bodyColors.LeftArmColor3,
		LeftHand = bodyColors.LeftArmColor3,
	}

	for name, color in pairs(mapping) do
		local part = arms:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

local function ensureArms()
	if arms and arms.Parent then
		return arms
	end

	local camera = workspace.CurrentCamera
	local template = ReplicatedStorage:FindFirstChild(ARMS_NAME)
	if not (camera and template) then
		return nil
	end

	local rig = template:Clone()

	-- 统一缩放。
	--
	-- 用引擎的 `Model:ScaleTo()`，**不要手写**"部件尺寸 ×s、C0/C1 位置 ×s"：
	-- C0 和 C1 各自带旋转，`T(a·s)·Ra · (T(b·s)·Rb)⁻¹` 并不等于 `T((a−b)·s)`，
	-- 手写出来位置会偏——实测偏了 0.27 studs，而且看起来只是"手臂位置有点怪"，
	-- 很难归因。ScaleTo 会正确处理关节链。
	if RIG_SCALE ~= 1 then
		rig:ScaleTo(RIG_SCALE)
	end

	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			-- 只有根节点锚定。其余部件一旦锚定就不会被 Motor6D 驱动。
			if descendant.Name ~= "Root" then
				descendant.Anchored = false
				descendant.Massless = true
			end
		end
	end

	rig.Parent = camera
	arms = rig
	applySkin()
	return rig
end

local function detachWeapon()
	if weaponJoint then
		weaponJoint:Destroy()
	end
	if weaponPart then
		weaponPart:Destroy()
	end
	weaponJoint, weaponPart, currentWeapon = nil, nil, nil
end

-- 装备指定武器。传 nil 或未知 id 会卸下武器但保留手臂。
function ViewModel.equip(weaponId)
	local weapon = Weapons.get(weaponId)
	local rig = ensureArms()

	if not (rig and weapon) then
		detachWeapon()
		return
	end

	if currentWeapon == weapon and weaponPart and weaponPart.Parent then
		return
	end

	detachWeapon()

	local template = ReplicatedStorage:FindFirstChild(weapon.viewmodel)
	if not template then
		warn("[ViewModel] ReplicatedStorage 里找不到武器模型: " .. tostring(weapon.viewmodel))
		return
	end

	local sourcePart = template.PrimaryPart or template:FindFirstChildWhichIsA("BasePart")
	if not sourcePart then
		warn("[ViewModel] " .. template.Name .. " 里没有可用的部件")
		return
	end

	local hand = rig:FindFirstChild("RightHand")
	if not hand then
		warn("[ViewModel] 骨架里没有 RightHand")
		return
	end

	local part = sourcePart:Clone()
	part.Name = "Weapon"
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = part.Size * weapon.viewmodelScale
	part.Parent = rig

	-- viewmodelPose 的含义在这里变了：从"整个枪相对相机"变成"枪相对右手"。
	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponGrip"
	motor.Part0 = hand
	motor.Part1 = part
	motor.C0 = weapon.viewmodelPose
	motor.C1 = CFrame.new()
	motor.Parent = hand

	weaponPart = part
	weaponJoint = motor
	currentWeapon = weapon
end

function ViewModel.getWeaponId()
	return currentWeapon and currentWeapon.displayName or nil
end

-- 枪口大致位置：从武器部件中心沿相机朝向往前推半个身位。
-- 模型本身没有枪口标记，所以这是个近似值——够放枪口火焰和音效。
function ViewModel.getMuzzlePosition()
	if not (weaponPart and currentWeapon) then
		return nil
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	return weaponPart.Position + camera.CFrame.LookVector * (weaponPart.Size.Z * 0.5)
end

-- 重生后 BodyColors 可能变，重新套一次肤色
player.CharacterAdded:Connect(function()
	task.defer(applySkin)
end)

RunService.RenderStepped:Connect(function()
	if not arms or not arms.Parent then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local root = arms:FindFirstChild("Root")
	if not root then
		return
	end

	-- 只动根节点，其余部件由关节跟随
	root.CFrame = camera.CFrame * RIG_POSE
end)

return ViewModel
