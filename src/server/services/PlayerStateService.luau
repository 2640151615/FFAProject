-- 每名玩家的对局状态。本任务只负责维护状态，不含任何战斗逻辑。
--
-- 战斗侧的写接口（applyDamage / markDead）由 Task 7 按需补上——
-- Task 5 只定义了读接口，是预检扫描发现的一处消费者缺口。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local PlayerStateService = {}

local states = {}

local function newState()
	return {
		health = 100,
		score = 0,
		weaponId = Weapons.Default,
		protectedUntil = 0,
		alive = true,
	}
end

-- 幂等：重复调用返回同一份状态，不会重置。
function PlayerStateService.ensure(player)
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

function PlayerStateService.get(player)
	return states[player]
end

Players.PlayerAdded:Connect(function(player)
	PlayerStateService.ensure(player)
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

-- 处理本脚本在已有玩家之后才加载的情况
for _, player in ipairs(Players:GetPlayers()) do
	PlayerStateService.ensure(player)
end

return PlayerStateService
