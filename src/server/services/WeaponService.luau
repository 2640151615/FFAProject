-- 开火的两道闸：令牌桶限速 + 射速间隔。
--
-- 判定（canFire）与提交（consumeFire）**刻意分离**：
-- 判定阶段只查不消耗，后续任何一步失败（位置回溯、射线、扣血）都不该扣掉玩家的额度。
-- 这也是 RateLimiter 需要 peek 的原因。
--
-- 两道闸都在服务器上。客户端发来的时间戳只用于位置回溯，不能用来绕过射速。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local RateLimiter = require(ReplicatedStorage:WaitForChild("RateLimiter"))

local WeaponService = {}

local limiters = {}
local lastFireAt = {}

local function ensure(player)
	if not limiters[player] then
		limiters[player] = RateLimiter.new(Config.MaxRequestsPerSecond, Config.RequestBurst)
		lastFireAt[player] = nil
	end
end

-- fireRate 的单位是"发/分"
local function fireInterval(weapon)
	return 60 / weapon.fireRate
end

function WeaponService.canFire(player, now, weapon)
	ensure(player)

	if not limiters[player]:peek(now) then
		return false
	end

	local last = lastFireAt[player]
	if last ~= nil and now - last < fireInterval(weapon) then
		return false
	end

	return true
end

-- 只有真正放行的一枪才调用，并且呼叫方必须保证此刻 canFire 刚刚通过。
function WeaponService.consumeFire(player, now)
	ensure(player)
	limiters[player]:allow(now)
	lastFireAt[player] = now
end

Players.PlayerRemoving:Connect(function(player)
	limiters[player] = nil
	lastFireAt[player] = nil
end)

return WeaponService
