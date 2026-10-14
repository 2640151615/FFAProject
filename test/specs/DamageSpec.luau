-- Task 3：按部件的伤害计算

local kit = require(script.Parent.Parent.TestKit)
local describe, it, expect = kit.describe, kit.it, kit.expect

describe("Damage", function()
	it("爆头吃爆头倍率", function()
		local Damage = kit.load("Damage")
		local Weapons = kit.load("Weapons")
		expect(Damage.compute(Weapons.get("Rifle"), "Head")):toBeCloseTo(24 * 1.8)
		expect(Damage.compute(Weapons.get("Pistol"), "Head")):toBeCloseTo(34 * 2)
	end)

	it("躯干走身体倍率表", function()
		local Damage = kit.load("Damage")
		local Weapons = kit.load("Weapons")
		expect(Damage.compute(Weapons.get("Rifle"), "Torso")):toBeCloseTo(24 * Damage.PartMultipliers.Torso)
	end)

	-- Review Focus 第 5 条：未知部件必须回退到基础伤害，而不是返回 nil 导致扣血为 NaN。
	it("未知部件回退到基础伤害，而不是 NaN", function()
		local Damage = kit.load("Damage")
		local Weapons = kit.load("Weapons")
		local d = Damage.compute(Weapons.get("Rifle"), "SomeDecoration")
		expect(d):toBe(24)
		expect(d == d):toBe(true) -- NaN 不等于自己
	end)

	it("R6 六个部件都有倍率", function()
		local Damage = kit.load("Damage")
		for _, part in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
			expect(Damage.PartMultipliers[part] ~= nil):toBe(true)
		end
	end)

	it("每把武器的伤害都为正", function()
		local Damage = kit.load("Damage")
		local Weapons = kit.load("Weapons")
		for _, def in pairs(Weapons.Definitions) do
			expect(Damage.compute(def, "Torso") > 0):toBe(true)
		end
	end)

	it("近战不吃爆头倍率（Knife 倍率刻意取 1）", function()
		local Damage = kit.load("Damage")
		local Weapons = kit.load("Weapons")
		expect(Damage.compute(Weapons.get("Knife"), "Head")):toBeCloseTo(55)
	end)
end)

return true
