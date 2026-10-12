-- 出生与重生，以及出生保护。
--
-- 出生保护：短暂无敌，**开火或移动即失效**（由 Task 8 接线调用 breakProtection）。
-- 不做保护，FFA 里就是堵出生点屠杀；做成永久无敌又会被当免死金牌滥用。
--
-- 时间基准统一用 workspace:GetServerTimeNow()——它和客户端发来的开火时间戳同一套时钟。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PlayerStateService = require(script.Parent.PlayerStateService)

local SpawnService = {}

local function now()
	return workspace:GetServerTimeNow()
end

-- 竞技公平：剥掉玩家的配件（帽子 / 头发）。
--
-- 配件会改变命中剪影。`Pal Hair` 这类配件的 Handle 就在头的位置，
-- 射线有可能先命中配件而不是头——那样一次本该爆头的枪（伤害 × headshotMultiplier）
-- 会退化成普伤。戴不戴帽子不该影响对枪结果。
--
-- 用 DescendantAdded 兜底：引擎有时在 CharacterAdded 之后才把配件挂上来，
-- 只在 CharacterAdded 那一刻扫一遍会漏。
local function stripAccessories(character)
	local function strip(instance)
		if instance:IsA("Accessory") then
			instance:Destroy()
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		strip(descendant)
	end
	character.DescendantAdded:Connect(strip)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(stripAccessories)
	if player.Character then
		stripAccessories(player.Character)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
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
