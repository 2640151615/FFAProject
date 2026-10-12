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

-- 把玩家外观归一到"朴素 R6 方块人"。
--
-- 剥掉三类东西，理由各不相同：
--
--   1. `Accessory`（帽子/头发）——竞技公平。配件的 Handle 就在头的位置，
--      射线可能先命中配件而不是头，把本该爆头的枪（伤害 × headshotMultiplier）
--      退化成普伤。戴不戴帽子不该影响对枪结果。
--
--   2. `CharacterMesh`——外观一致，也是这次真正被漏掉的一项。
--      R6 骨架本身是方块人，但 CharacterMesh 会在**视觉上**把方块部件替换成网格模型
--      （服装包），于是出现"骨架是 R6、看着却不像 R6"。它不改变碰撞盒，
--      所以命中判定是对的，只是看起来不对。
--
--   3. `Shirt` / `Pants`——同上，而且深色服装本身就是一种伪装优势。
--
-- **保留 `BodyColors`**：它只是给方块部件上色，不改变形状，还能帮助分辨玩家。
--
-- 用 DescendantAdded 兜底：引擎有时在 CharacterAdded 之后才把这些挂上来，
-- 只在那一刻扫一遍会漏。
local STRIPPED_CLASSES = {
	Accessory = true,
	CharacterMesh = true,
	Shirt = true,
	Pants = true,
}

local function normalizeAppearance(character)
	local function strip(instance)
		if STRIPPED_CLASSES[instance.ClassName] then
			instance:Destroy()
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		strip(descendant)
	end
	character.DescendantAdded:Connect(strip)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(normalizeAppearance)
	if player.Character then
		normalizeAppearance(player.Character)
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
