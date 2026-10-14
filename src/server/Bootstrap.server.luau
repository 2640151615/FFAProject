-- 服务器启动装配。按依赖顺序 require 各服务，让它们的副作用生效。
--
-- 关闭引擎的自动出生：出生时机必须由 SpawnService 掌握，
-- 否则玩家加入时会被引擎和 SpawnService 各生一次。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

-- Net 在 require 时就把远程事件建出来，必须早于任何客户端连接。
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local services = script.Parent:WaitForChild("services")

-- 这几个模块的 require 本身带副作用（挂事件、起位置记录循环），
-- 即使返回值没被用到也必须 require。
require(services:WaitForChild("PlayerStateService"))
local SpawnService = require(services:WaitForChild("SpawnService"))
require(services:WaitForChild("WeaponService"))
local CombatService = require(services:WaitForChild("CombatService"))

-- 客户端只发"意图"。入参一律不可信——具体校验在 resolveShot 内部逐条做。
Net.Fire.OnServerEvent:Connect(function(player, direction, timestamp)
	CombatService.resolveShot(player, direction, timestamp)
end)

Players.PlayerAdded:Connect(function(player)
	SpawnService.spawn(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	SpawnService.spawn(player)
end
