-- Task 10：后坐力曲线
--
-- 被测模块要走 Loader，因为它同步到 StarterPlayerScripts 而不是 ReplicatedStorage。

local kit = require(script.Parent.Parent.TestKit)
local load = require(script.Parent.Parent.Loader)
local describe, it, expect = kit.describe, kit.it, kit.expect

describe("Recoil", function()
	it("开火产生向上的偏移", function()
		local Recoil = load("Recoil")
		local Weapons = load("Weapons")

		local r = Recoil.new()
		r:kick(Weapons.get("Rifle"))
		local delta = r:update(0)
		expect(delta.Y > 0):toBe(true) -- 上抬
	end)

	it("没有开火时不产生偏移", function()
		local Recoil = load("Recoil")
		local r = Recoil.new()
		expect(r:update(0.016)):toEqual(Vector2.new(0, 0))
	end)

	it("会回落归零", function()
		local Recoil = load("Recoil")
		local Weapons = load("Weapons")

		local r = Recoil.new()
		r:kick(Weapons.get("Rifle"))
		for _ = 1, 200 do
			r:update(0.016)
		end
		local delta = r:update(0.016)
		expect(math.abs(delta.Y) < 0.01):toBe(true)
		expect(math.abs(delta.X) < 0.01):toBe(true)
	end)

	it("reset 立即清零", function()
		local Recoil = load("Recoil")
		local Weapons = load("Weapons")

		local r = Recoil.new()
		r:kick(Weapons.get("Rifle"))
		r:reset()
		expect(r:update(0.016)):toEqual(Vector2.new(0, 0))
	end)

	-- 近战（Knife）的两个后坐力系数都是 0，所以踢不动相机
	it("近战踢不动相机", function()
		local Recoil = load("Recoil")
		local Weapons = load("Weapons")

		local r = Recoil.new()
		r:kick(Weapons.get("Knife"))
		expect(r:update(0.016)):toEqual(Vector2.new(0, 0))
	end)

	it("连续开火会累积", function()
		local Recoil = load("Recoil")
		local Weapons = load("Weapons")

		local rifle = Weapons.get("Rifle")

		local single = Recoil.new()
		single:kick(rifle)
		local one = single:update(0).Y

		local burst = Recoil.new()
		for _ = 1, 5 do
			burst:kick(rifle)
		end
		local five = burst:update(0).Y

		expect(five > one):toBe(true)
	end)
end)

return true
