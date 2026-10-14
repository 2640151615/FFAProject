-- 令牌桶限速器。
--
-- 用在 Fire 请求上的第二道闸（射速校验之外）。`now` 由调用方传入单调递增的秒数，
-- 而不是内部读时钟——这样它是纯函数，可以直接单测。
--
-- 关键点：回填必须封顶于 capacity。玩家挂机一小时后回来，只该拿到 burst 个令牌，
-- 而不是 rate * 3600 个——否则限速形同虚设。

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(ratePerSecond, burst)
	local self = setmetatable({}, RateLimiter)
	self.rate = ratePerSecond
	self.capacity = burst
	self.tokens = burst
	self.lastRefill = nil -- 首次调用时初始化，避免把"创建时刻"当成 0
	return self
end

-- 到 now 为止应有的令牌数。纯计算，不改状态。
function RateLimiter:refilled(now)
	if self.lastRefill == nil or now <= self.lastRefill then
		return self.tokens
	end
	return math.min(self.capacity, self.tokens + (now - self.lastRefill) * self.rate)
end

-- 只读查询：会不会放行。
--
-- 给 WeaponService.canFire 用——判定阶段只查不消耗，后续任何一步失败
-- 都不该扣掉玩家的限速额度。不推进 lastRefill，也不改 tokens。
function RateLimiter:peek(now)
	return self:refilled(now) >= 1
end

function RateLimiter:allow(now)
	if self.lastRefill == nil then
		self.lastRefill = now
	elseif now > self.lastRefill then
		self.tokens = self:refilled(now)
		self.lastRefill = now
	end

	if self.tokens >= 1 then
		self.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
