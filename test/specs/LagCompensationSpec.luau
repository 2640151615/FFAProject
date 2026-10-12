-- Task 4：服务器位置回溯

local kit = require(script.Parent.Parent.TestKit)
local describe, it, expect = kit.describe, kit.it, kit.expect

describe("LagCompensation", function()
	it("取回最近一次记录", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(1)
		h:record("p1", Vector3.new(0, 0, 0), 10)
		h:record("p1", Vector3.new(5, 0, 0), 10.1)
		expect(h:sample("p1", 10.1)):toEqual(Vector3.new(5, 0, 0))
	end)

	it("两点之间线性插值", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(1)
		h:record("p1", Vector3.new(0, 0, 0), 10)
		h:record("p1", Vector3.new(10, 0, 0), 11)
		local mid = h:sample("p1", 10.5)
		expect(mid.X):toBeCloseTo(5, 0.001)
		expect(mid.Y):toBeCloseTo(0, 0.001)
		expect(mid.Z):toBeCloseTo(0, 0.001)
	end)

	-- Review Focus 第 3 条：sample 必须只读，重复采样同一时刻结果必须一致。
	it("重复采样同一时刻结果相同（幂等）", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(1)
		h:record("p1", Vector3.new(0, 0, 0), 10)
		h:record("p1", Vector3.new(10, 0, 0), 11)
		local a = h:sample("p1", 10.5)
		local b = h:sample("p1", 10.5)
		expect(a):toEqual(b)
		-- 采样不得改动历史：再采一次还是要一样
		expect(h:sample("p1", 10.5)):toEqual(a)
	end)

	it("未知 key 返回 nil", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(1)
		expect(h:sample("nobody", 10)):toBe(nil)
	end)

	it("超出窗口的旧记录被丢弃", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(0.5)
		h:record("p1", Vector3.new(0, 0, 0), 10)
		h:record("p1", Vector3.new(1, 0, 0), 20)
		expect(h:sample("p1", 10)):toBe(nil)
	end)

	it("早于最早记录的采样返回 nil", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(10)
		h:record("p1", Vector3.new(7, 0, 0), 100)
		expect(h:sample("p1", 90)):toBe(nil)
	end)

	it("多个 key 互不干扰", function()
		local LagCompensation = kit.load("LagCompensation")
		local h = LagCompensation.new(10)
		h:record("a", Vector3.new(1, 0, 0), 100)
		h:record("b", Vector3.new(2, 0, 0), 100)
		expect(h:sample("a", 100)):toEqual(Vector3.new(1, 0, 0))
		expect(h:sample("b", 100)):toEqual(Vector3.new(2, 0, 0))
	end)
end)

return true
