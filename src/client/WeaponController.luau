-- 开火：把"意图"发给服务器。本地不做命中判定——那由服务器裁决。
--
-- 只发**方向 + 时间戳**。射线原点由服务器自己从射手头部取，客户端说了不算；
-- 时间戳服务器还会夹在位置历史窗口内。
--
-- 本地负责的是**手感**：开火瞬间把后坐力踢进相机，不等服务器回包。
--
-- 还没接（属后续任务）：枪口火焰 / 音效（Task 13）、连发（automatic）。
-- 连发需要 Input 暴露"按下 / 松开"两个语义，跟动画一起做更顺。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Input = require(script.Parent.Input)
local ViewModel = require(script.Parent.ViewModel)
local Recoil = require(script.Parent.Recoil)
local AimAssist = require(script.Parent.AimAssist)
local SoundKit = require(script.Parent.SoundKit)

local WeaponController = {}

local player = Players.LocalPlayer
local currentWeaponId = Weapons.Default
local recoil = Recoil.new()

-- 辅助瞄准只给触屏。
--
-- 设计文档定死了：PC 的手感是竞技基准，辅助是给触屏的补偿手段，
-- 不能反过来。PC 一旦也走辅助，基准就歪了——那种"两边都觉得不对"的歪法。
--
-- 每次开火时读，而不是模块加载时读一次：触屏笔记本这类设备可能中途
-- 换用键盘鼠标，加载时的快照会一直用错。
local function usesTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local aimAssist = AimAssist.new(Config.AimAssistMaxAngle, Config.AimAssistStrength)

-- 收集可以辅助的目标方向。
--
-- 除了距离和锥角，还要**射线确认没被挡住**——否则隔着墙也会被吸，
-- 等于给触屏玩家发了一个"墙后有没有人"的探测器，那是白送信息。
local function aimCandidates(origin, aim)
	local character = player.Character

	-- Camera 也在 Workspace 下，而视图模型挂在 Camera 上。
	-- 不把 Camera 排除掉的话，射线第一件事就是打中自己的枪，
	-- 于是每个目标都被判成"被挡住"——辅助静默失效，而且正常游玩下完全看不出。
	local filter = { workspace.CurrentCamera }
	if character then
		table.insert(filter, character)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	local withinCone = math.cos(math.rad(45))
	local candidates = {}

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherCharacter = other.Character
			local head = otherCharacter and otherCharacter:FindFirstChild("Head")
			if head then
				local delta = head.Position - origin
				local distance = delta.Magnitude

				if distance > 0.1 and distance <= Config.AimAssistRange then
					local unit = delta.Unit
					if unit:Dot(aim) >= withinCone then
						local hit = workspace:Raycast(origin, delta, params)
						local blocked = hit ~= nil and not hit.Instance:IsDescendantOf(otherCharacter)
						if not blocked then
							table.insert(candidates, unit)
						end
					end
				end
			end
		end
	end

	return candidates
end

function WeaponController.getWeaponId()
	return currentWeaponId
end

function WeaponController.onFire()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local direction = camera.CFrame.LookVector

	-- 触屏才做辅助。它在**开火瞬间**把方向轻推一点，而不是每帧拽相机——
	-- 后者就是自动跟枪了，撞反目标。
	if usesTouch() then
		direction = aimAssist:apply(direction, aimCandidates(camera.CFrame.Position, direction), false)
	end

	-- 本地立刻给手感。方向取当前的相机朝向——包括此刻已经叠加的后坐力，
	-- 也就是"你瞄哪打哪"，而不是把枪口硬掰回原位。
	local weapon = Weapons.get(currentWeaponId)
	recoil:kick(weapon)

	-- 自己的枪声走本地音（不分方位）：它不该因为自己站的位置忽大忽小。
	-- 别人的枪声走世界音，那个才需要方位——由 SoundKit 那边按位置播。
	SoundKit.playLocal(weapon and weapon.fireSound, 0.5)

	Net.Fire:FireServer(direction, workspace:GetServerTimeNow())
end

function WeaponController.onSwitch(slot)
	local weaponId = Weapons.forSlot(slot)
	if weaponId then
		currentWeaponId = weaponId
		ViewModel.equip(weaponId)
	end
end

function WeaponController.init()
	ViewModel.equip(currentWeaponId)
	Input.onFire(WeaponController.onFire)
	Input.onSwitch(WeaponController.onSwitch)

	-- 默认相机脚本跑在 Camera 优先级；+1 让我们在它之后再叠加后坐力。
	--
	-- 这里施加的是**增量**而不是总量：`camera.CFrame` 本身就是相机脚本的状态源，
	-- 每帧被我们改过之后会成为下一帧的基准，施总量会复利式累积（实测确认）。
	local function applyRecoil(dt)
		local delta = recoil:update(dt)
		if delta.Magnitude < 1e-6 then
			return
		end

		local camera = workspace.CurrentCamera
		if camera then
			camera.CFrame = camera.CFrame
				* CFrame.Angles(math.rad(delta.Y), math.rad(delta.X), 0)
		end
	end
	RunService:BindToRenderStep("FFA_Recoil", Enum.RenderPriority.Camera.Value + 1, applyRecoil)

	-- 重生时相机被重设，累积的后坐力必须清零，否则相机会被突然拽一下
	player.CharacterAdded:Connect(function()
		recoil:reset()
	end)
end

return WeaponController
