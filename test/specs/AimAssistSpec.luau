-- Task 12：触屏弱辅助瞄准
--
-- 被测模块走 Loader（同步到 StarterPlayerScripts，不在 ReplicatedStorage）。
--
-- 这组测试最重要的不是功能，而是**给"弱"这个字上锁**：
-- 规格的反目标写死"不要变成自动瞄准大战"。所以角度上限那几条是硬约束，
-- 不是示例——实现者一旦写成"把准星吸到目标身上"，这里会立刻红。

local kit = require(script.Parent.Parent.TestKit)
local load = require(script.Parent.Parent.Loader)
local describe, it, expect = kit.describe, kit.it, kit.expect

local function angleBetween(a, b)
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

describe("AimAssist", function()
	it("没有候选目标时方向完全不变", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 0.5)
		local aim = Vector3.new(0, 0, -1)
		expect(assist:apply(aim, {}, false)):toEqual(aim)
	end)

	-- 核心约束：即使用户把强度拉满，偏转也绝不允许超过角度上限。
	-- 目标偏 90 度——一个"真·自动瞄准"的实现会直接吸过去。
	it("偏转永远不超过角度上限", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 1.0)
		local aim = Vector3.new(0, 0, -1)
		local sideways = Vector3.new(-1, 0, 0)

		local out = assist:apply(aim, { sideways }, false)
		expect(angleBetween(aim, out) <= 3.001):toBe(true)
	end)

	it("目标正后方时也不超过上限", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 1.0)
		local aim = Vector3.new(0, 0, -1)
		local behind = Vector3.new(0, 0, 1)

		local out = assist:apply(aim, { behind }, false)
		expect(angleBetween(aim, out) <= 3.001):toBe(true)
	end)

	it("开镜时辅助更弱", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 1.0)
		local aim = Vector3.new(0, 0, -1)
		local near = Vector3.new(0.1, 0, -1)

		local hip = assist:apply(aim, { near }, false)
		local ads = assist:apply(aim, { near }, true)

		expect(angleBetween(aim, ads) <= angleBetween(aim, hip) + 1e-6):toBe(true)
	end)

	it("strength 为 0 时完全不动", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 0)
		local aim = Vector3.new(0, 0, -1)
		expect(assist:apply(aim, { Vector3.new(0.1, 0, -1) }, false)):toEqual(aim)
	end)

	it("多个候选时朝最近的那个偏，且仍不超上限", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 1.0)
		local aim = Vector3.new(0, 0, -1)
		local nearMiss = Vector3.new(0.05, 0, -1) -- 很近
		local farOff = Vector3.new(-1, 0, 0) -- 很远

		local out = assist:apply(aim, { farOff, nearMiss }, false)
		expect(angleBetween(aim, out) <= 3.001):toBe(true)
		-- 偏转后的方向应当离近的那个更近，而不是被远处目标拉走
		expect(out.Unit:Dot(nearMiss.Unit) > aim.Unit:Dot(nearMiss.Unit)):toBe(true)
	end)

	it("候选里有 nil 或零向量也不报错", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 1.0)
		local aim = Vector3.new(0, 0, -1)

		local ok = pcall(function()
			assist:apply(aim, { nil, Vector3.new(0, 0, 0) }, false)
		end)
		expect(ok):toBe(true)
	end)

	it("结果始终是单位向量", function()
		local AimAssist = load("AimAssist")
		local assist = AimAssist.new(3, 1.0)
		local aim = Vector3.new(0, 0, -5) -- 故意不是单位长度
		local out = assist:apply(aim, { Vector3.new(0.2, 0, -1) }, false)
		expect(math.abs(out.Magnitude - 1) < 1e-6):toBe(true)
	end)
end)

return true
