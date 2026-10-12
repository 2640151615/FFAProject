-- Task 1：共享常量与武器定义
--
-- 注意：spec 模块**必须返回一个值**。require 一个不返回值的 ModuleScript 会报
-- "Module code did not return exactly one value"。
-- 更要紧的是：在 Studio edit 模式下经 MCP 改 Source **不会**让 require 缓存失效，
-- 所以一旦某个 spec 以错误的状态被 require 过，后续怎么改都还是那个旧错误——
-- 只能换一个新实例（改文件名或删掉重建）。spec 从一开始就要写对。

local harness = require(script.Parent.Parent.harness)
local describe, it, expect = harness.describe, harness.it, harness.expect
local Weapons = require(game:GetService("ReplicatedStorage").Weapons)

describe("Weapons", function()
	it("按 id 取到定义", function()
		expect(Weapons.get("Rifle").damage):toBe(24)
	end)

	it("垃圾输入返回 nil 而不是报错", function()
		expect(Weapons.get(nil)):toBe(nil)
		expect(Weapons.get(42)):toBe(nil)
		expect(Weapons.get("NoSuchGun")):toBe(nil)
	end)

	it("槽位映射与 Slots 表一致", function()
		expect(Weapons.forSlot(1)):toBe(Weapons.Slots[1])
		expect(Weapons.forSlot(99)):toBe(nil)
		expect(Weapons.forSlot("x")):toBe(nil)
	end)

	it("只有 ranged 用弹药", function()
		expect(Weapons.usesAmmo(Weapons.get("Rifle"))):toBe(true)
		expect(Weapons.usesAmmo(Weapons.get("Knife"))):toBe(false)
		expect(Weapons.usesAmmo(nil)):toBe(false)
	end)

	it("竞技向：首发零扩散", function()
		for _, def in pairs(Weapons.Definitions) do
			expect(def.firstShotSpread):toBe(0)
		end
	end)

	-- 预检裁定的那 5 个表现层字段：Task 9（ViewModel）与 Task 13（SoundKit）消费它们。
	-- 没有这条测试，字段漏了要等到 M3 实机截图才发现。
	it("每把武器都有表现层字段", function()
		for _, def in pairs(Weapons.Definitions) do
			expect(typeof(def.viewmodel)):toBe("string")
			expect(typeof(def.viewmodelScale)):toBe("number")
			expect(def.viewmodelPose ~= nil):toBe(true)
			expect(typeof(def.fireSound)):toBe("string")
		end
	end)
end)

return true
