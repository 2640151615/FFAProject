-- 开火：把"意图"发给服务器。本地不做命中判定——那由服务器裁决。
--
-- 只发**方向 + 时间戳**。射线原点由服务器自己从射手头部取，客户端说了不算；
-- 时间戳服务器还会夹在位置历史窗口内。
--
-- 本任务只做最小闭环。以下都还没接，属 M3：
--   枪口火焰 / 音效（Task 13）、视图模型（Task 9）、后坐力（Task 10）、
--   连发（automatic）。连发需要 Input 暴露"按下 / 松开"两个语义，
--   而那属于手感工作，跟后坐力一起做。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Input = require(script.Parent.Input)

local WeaponController = {}

local currentWeaponId = Weapons.Default

function WeaponController.getWeaponId()
	return currentWeaponId
end

function WeaponController.onFire()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	Net.Fire:FireServer(camera.CFrame.LookVector, workspace:GetServerTimeNow())
end

function WeaponController.onSwitch(slot)
	local weaponId = Weapons.forSlot(slot)
	if weaponId then
		currentWeaponId = weaponId
	end
end

function WeaponController.init()
	Input.onFire(WeaponController.onFire)
	Input.onSwitch(WeaponController.onSwitch)
end

return WeaponController
