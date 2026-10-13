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

local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Input = require(script.Parent.Input)
local ViewModel = require(script.Parent.ViewModel)
local Recoil = require(script.Parent.Recoil)

local WeaponController = {}

local player = Players.LocalPlayer
local currentWeaponId = Weapons.Default
local recoil = Recoil.new()

function WeaponController.getWeaponId()
	return currentWeaponId
end

function WeaponController.onFire()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- 本地立刻给手感。方向取当前的相机朝向——包括此刻已经叠加的后坐力，
	-- 也就是"你瞄哪打哪"，而不是把枪口硬掰回原位。
	recoil:kick(Weapons.get(currentWeaponId))

	Net.Fire:FireServer(camera.CFrame.LookVector, workspace:GetServerTimeNow())
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
