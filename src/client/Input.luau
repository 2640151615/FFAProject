-- 输入抽象层。
--
-- 业务代码只订阅语义回调，不直接碰鼠标或触摸。这一层是移动端要求逼出来的：
-- WeaponController 不该知道开火来自鼠标左键还是屏幕上的手指。
--
-- 移动与视角**不在这里**——交给 Roblox 内置 PlayerModule 的动态摇杆。
-- 自己造虚拟摇杆是"屏幕糊满按钮"的常见来源。

local ContextActionService = game:GetService("ContextActionService")

local Input = {}

local handlers = {
	fire = {},
	reload = {},
	switch = {},
}

local function emit(kind, ...)
	for _, fn in ipairs(handlers[kind]) do
		fn(...)
	end
end

function Input.onFire(fn)
	table.insert(handlers.fire, fn)
end

function Input.onReload(fn)
	table.insert(handlers.reload, fn)
end

function Input.onSwitch(fn)
	table.insert(handlers.switch, fn)
end

local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
}

function Input.init()
	-- createTouchButton = true 会让 ContextActionService 自动为触屏生成按钮，
	-- 不需要我们自己画 UI。
	ContextActionService:BindAction("FFA_Fire", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			emit("fire")
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1)

	ContextActionService:BindAction("FFA_Reload", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			emit("reload")
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.R)

	for slot, keyCode in ipairs(SLOT_KEYS) do
		ContextActionService:BindAction("FFA_Slot" .. slot, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				emit("switch", slot)
			end
			return Enum.ContextActionResult.Pass
		end, false, keyCode)
	end
end

return Input
