-- 出生与重生，以及出生保护。
--
-- 出生保护：短暂无敌，**开火或移动即失效**（由 Task 8 接线调用 breakProtection）。
-- 不做保护，FFA 里就是堵出生点屠杀；做成永久无敌又会被当免死金牌滥用。
--
-- 时间基准统一用 workspace:GetServerTimeNow()——它和客户端发来的开火时间戳同一套时钟。

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PlayerStateService = require(script.Parent.PlayerStateService)

local SpawnService = {}

local function now()
	return workspace:GetServerTimeNow()
end

-- 出生点选择交给引擎：LoadCharacter 会在场上的 SpawnLocation 之间随机取点。
function SpawnService.spawn(player)
	local state = PlayerStateService.ensure(player)
	state.alive = true
	state.health = 100
	state.protectedUntil = now() + Config.SpawnProtectionTime

	player:LoadCharacter()
end

-- 开火或移动时调用，立刻解除保护。
function SpawnService.breakProtection(player)
	local state = PlayerStateService.get(player)
	if state then
		state.protectedUntil = 0
	end
end

function SpawnService.isProtected(player)
	local state = PlayerStateService.get(player)
	if not state then
		return false
	end
	return now() < state.protectedUntil
end

return SpawnService
