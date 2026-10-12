-- 客户端启动装配。顺序固定：先锁定第一人称，再装输入。

local FirstPerson = require(script.Parent.FirstPerson)
local Input = require(script.Parent.Input)

FirstPerson.lock()
Input.init()
