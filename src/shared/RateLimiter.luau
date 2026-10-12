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

function RateLimiter:allow(now)
	if self.lastRefill == nil then
		self.lastRefill = now
	elseif now > self.lastRefill then
		local elapsed = now - self.lastRefill
		self.tokens = math.min(self.capacity, self.tokens + elapsed * self.rate)
		self.lastRefill = now
	end

	if self.tokens >= 1 then
		self.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
