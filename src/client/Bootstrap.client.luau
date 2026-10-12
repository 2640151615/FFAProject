-- 客户端启动装配。
--
-- 顺序：先锁第一人称，再装武器控制器（注册回调），最后才 bind 输入——
-- 反过来写的话，输入在被按下之前就已经绑定好了，中间那一小段窗口里回调是空的。

local FirstPerson = require(script.Parent.FirstPerson)
local Input = require(script.Parent.Input)
local WeaponController = require(script.Parent.WeaponController)

FirstPerson.lock()
WeaponController.init()
Input.init()
