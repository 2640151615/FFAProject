-- 远程事件的集中定义。所有跨端通信都从这一个文件进出。
--
-- 名字一旦定下就不要改——改一次要同时动服务端和客户端，而且很容易只改一边。
-- `ScoreChanged` 直到 M5 才有人消费，但先定义好：远程事件名不该等到用的时候才拍。
--
-- 服务器负责创建实体，客户端只等待。客户端自己 new 出来的实例不会复制到服务器。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local function define(name)
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
		return remote
	end

	-- 客户端：等服务器把它建出来
	return ReplicatedStorage:WaitForChild(name)
end

Net.Fire = define("Fire") -- 客户端 → 服务器：开火意图（朝向 + 时间戳）
Net.HitConfirm = define("HitConfirm") -- 服务器 → 客户端：命中反馈
Net.ScoreChanged = define("ScoreChanged") -- 服务器 → 客户端：分数变更（M5 消费）

return Net
