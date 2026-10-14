-- Task 2：令牌桶限速器

local kit = require(script.Parent.Parent.TestKit)
local describe, it, expect = kit.describe, kit.it, kit.expect

describe("RateLimiter", function()
	it("突发额度内全放行，超出即拒", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(20, 40)
		for _ = 1, 40 do
			expect(rl:allow(0)):toBe(true)
		end
		expect(rl:allow(0)):toBe(false)
	end)

	it("按速率回填", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(20, 5)
		for _ = 1, 5 do rl:allow(0) end
		expect(rl:allow(0)):toBe(false)
		expect(rl:allow(0.05)):toBe(true) -- 20/秒 => 0.05 秒回填 1 个
	end)

	it("长时间闲置后令牌封顶于 burst，不累积", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(20, 5)
		for _ = 1, 5 do rl:allow(0) end
		expect(rl:allow(3600)):toBe(true)
		for _ = 1, 4 do expect(rl:allow(3600)):toBe(true) end
		expect(rl:allow(3600)):toBe(false) -- 不能因为等了一小时就放行 72000 次
	end)

	it("连续拒绝不改变状态", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(1, 1)
		expect(rl:allow(0)):toBe(true)
		expect(rl:allow(0)):toBe(false)
		expect(rl:allow(0)):toBe(false)
		expect(rl:allow(1)):toBe(true) -- 一秒后回填 1 个
	end)
	-- peek 是给 WeaponService.canFire 用的：判定阶段只查不消耗，
	-- 任何后续步骤失败都不能扣掉玩家的限速额度。
	it("peek 不消耗令牌", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(1, 2)
		expect(rl:peek(0)):toBe(true)
		expect(rl:peek(0)):toBe(true) -- 反复查看仍然是 true
		expect(rl:allow(0)):toBe(true) -- 真正消耗时才减
		expect(rl:allow(0)):toBe(true)
		expect(rl:peek(0)):toBe(false) -- 两个令牌用完了
	end)

	it("peek 反映回填且不推进时钟", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(1, 1)
		expect(rl:allow(0)):toBe(true)
		expect(rl:peek(0)):toBe(false)
		expect(rl:peek(1)):toBe(true) -- 一秒后回填
		expect(rl:peek(1)):toBe(true) -- 再查一次仍为 true，说明 peek 没消耗
		expect(rl:allow(1)):toBe(true) -- 紧接着真消耗，仍然拿得到
		expect(rl:peek(1)):toBe(false)
	end)

	it("peek 也受 burst 封顶", function()
		local RateLimiter = kit.load("RateLimiter")
		local rl = RateLimiter.new(20, 5)
		for _ = 1, 5 do rl:allow(0) end
		expect(rl:peek(3600)):toBe(true)
		expect(rl:allow(3600)):toBe(true)
		for _ = 1, 4 do expect(rl:allow(3600)):toBe(true) end
		expect(rl:peek(3600)):toBe(false) -- 挂机一小时也只回填到 burst
	end)
end)

return true
