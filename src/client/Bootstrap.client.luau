-- 客户端启动装配。
--
-- 顺序：先锁第一人称，等相机就绪，再装武器控制器（含视图模型）与 HUD，最后才 bind 输入——
-- 反过来写的话，输入在被按下之前就已经绑定好了，中间那一小段窗口里回调是空的。

local FirstPerson = require(script.Parent.FirstPerson)
local Input = require(script.Parent.Input)
local WeaponController = require(script.Parent.WeaponController)
local HudController = require(script.Parent.HudController)

FirstPerson.lock()

-- 相机不一定在脚本启动的那一刻就绪；视图模型要挂到它下面。
if not workspace.CurrentCamera then
	workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
end

WeaponController.init()
HudController.init()
Input.init()
