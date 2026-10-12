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
end)

return true
