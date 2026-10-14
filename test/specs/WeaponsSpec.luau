-- Task 1：共享常量与武器定义
--
-- 被测模块一律走 kit.load(...)，不要直接 require：直接 require 会把代码
-- 冻在首次加载那一刻（Studio edit 模式下改源码不会让 require 缓存失效）。

local kit = require(script.Parent.Parent.TestKit)
local describe, it, expect = kit.describe, kit.it, kit.expect

describe("Weapons", function()
	it("按 id 取到定义", function()
		local Weapons = kit.load("Weapons")
		expect(Weapons.get("Rifle").damage):toBe(24)
	end)

	it("垃圾输入返回 nil 而不是报错", function()
		local Weapons = kit.load("Weapons")
		expect(Weapons.get(nil)):toBe(nil)
		expect(Weapons.get(42)):toBe(nil)
		expect(Weapons.get("NoSuchGun")):toBe(nil)
	end)

	it("槽位映射与 Slots 表一致", function()
		local Weapons = kit.load("Weapons")
		expect(Weapons.forSlot(1)):toBe(Weapons.Slots[1])
		expect(Weapons.forSlot(99)):toBe(nil)
		expect(Weapons.forSlot("x")):toBe(nil)
	end)

	it("只有 ranged 用弹药", function()
		local Weapons = kit.load("Weapons")
		expect(Weapons.usesAmmo(Weapons.get("Rifle"))):toBe(true)
		expect(Weapons.usesAmmo(Weapons.get("Knife"))):toBe(false)
		expect(Weapons.usesAmmo(nil)):toBe(false)
	end)

	it("竞技向：首发零扩散", function()
		local Weapons = kit.load("Weapons")
		for _, def in pairs(Weapons.Definitions) do
			expect(def.firstShotSpread):toBe(0)
		end
	end)

	-- 预检裁定的那 5 个表现层字段：Task 9（ViewModel）与 Task 13（SoundKit）消费它们。
	-- 没有这条测试，字段漏了要等到 M3 实机截图才发现。
	it("每把武器都有表现层字段", function()
		local Weapons = kit.load("Weapons")
		for _, def in pairs(Weapons.Definitions) do
			expect(typeof(def.viewmodel)):toBe("string")
			expect(typeof(def.viewmodelScale)):toBe("number")
			expect(def.viewmodelPose ~= nil):toBe(true)
			expect(typeof(def.fireSound)):toBe("string")
		end
	end)
end)

return true
