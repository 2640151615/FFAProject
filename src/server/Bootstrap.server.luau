-- 服务器启动装配。按依赖顺序 require 各服务，让它们的副作用（事件接线）生效。
--
-- 关闭引擎的自动出生：出生时机必须由 SpawnService 掌握，
-- 否则玩家加入时会被引擎和 SpawnService 各生一次。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

-- Net 在 require 时就把远程事件建出来，必须早于任何客户端连接。
require(ReplicatedStorage:WaitForChild("Net"))

local services = script.Parent:WaitForChild("services")
local SpawnService = require(services:WaitForChild("SpawnService"))

-- PlayerStateService 没有对外方法被这里调用，但必须被 require 才会挂上
-- PlayerAdded / PlayerRemoving 的接线。
require(services:WaitForChild("PlayerStateService"))

Players.PlayerAdded:Connect(function(player)
	SpawnService.spawn(player)
end)

-- 处理本脚本晚于已有玩家加载的情况
for _, player in ipairs(Players:GetPlayers()) do
	SpawnService.spawn(player)
end
