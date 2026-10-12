-- 服务器权威的命中判定。整个游戏最核心的一段。
--
-- 铁律：客户端只发"意图"（朝向 + 时间戳），不发"结果"。
-- 射线原点由服务器自己从射手角色上取——**不接受客户端传来的原点**，
-- 否则作弊器可以把射线起点挪到任何人背后。
--
-- 顺序严格，每一步都能独立失败；任何一步失败立即 return false，
-- 且不消耗限速额度（canFire 只查不消耗，consumeFire 才提交）。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Damage = require(ReplicatedStorage:WaitForChild("Damage"))
local LagCompensation = require(ReplicatedStorage:WaitForChild("LagCompensation"))

local WeaponService = require(script.Parent.WeaponService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local SpawnService = require(script.Parent.SpawnService)

local CombatService = {}

-- 位置历史窗口：1 秒足够吸收常见延迟抖动。
local HISTORY_MAX_AGE = 1
local HISTORY_INTERVAL = 1 / 30

local history = LagCompensation.new(HISTORY_MAX_AGE)

local function now()
	return workspace:GetServerTimeNow()
end

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- 以固定频率记录所有玩家的位置，供回溯使用。
-- Heartbeat 每一帧都跑，这里按累计时间降频到 30Hz——回溯不需要每帧精度。
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < HISTORY_INTERVAL then
		return
	end
	accumulated = 0

	local stamp = now()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player.Character)
		if root then
			history:record(player, root.Position, stamp)
		end
	end
end)

-- 射线原点取射手自己的头。没有头（异常状态）就退回躯干。
local function shooterOrigin(shooter)
	local character = shooter.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head then
		return head.Position
	end
	local root = rootOf(character)
	return root and root.Position or nil
end

-- 把其他玩家还原到 timestamp 那一刻：为每个部件造一个隐形临时碰撞盒，
-- 放在回溯后的位置。不移动真实角色——那会抖动、也会影响物理。
local function buildGhosts(shooter, origin, timestamp, range)
	local ghosts = {}
	local ghostInfo = {}

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= shooter and other.Character then
			local root = rootOf(other.Character)
			local sampled = root and history:sample(other, timestamp)

			-- 距离粗筛：够不着的玩家不必造碰撞盒
			if root and sampled and (sampled - origin).Magnitude <= range + 8 then
				local offset = sampled - root.Position
				for _, part in ipairs(other.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						local ghost = Instance.new("Part")
						ghost.Name = part.Name
						ghost.Size = part.Size
						ghost.CFrame = part.CFrame + offset
						ghost.Anchored = true
						ghost.CanCollide = false
						ghost.CanTouch = false
						ghost.CanQuery = true
						ghost.Transparency = 1
						ghost.Parent = workspace

						table.insert(ghosts, ghost)
						ghostInfo[ghost] = { owner = other, partName = part.Name }
					end
				end
			end
		end
	end

	return ghosts, ghostInfo
end

-- 返回 true 表示这一枪被服务器接受了（不代表命中）。
-- direction 来自客户端，其余一切由服务器决定。
function CombatService.resolveShot(shooter, direction, timestamp)
	-- 1. 射手活着？
	local shooterState = PlayerStateService.get(shooter)
	if not shooterState or not shooterState.alive then
		return false
	end

	local weapon = Weapons.get(shooterState.weaponId)
	if not weapon then
		return false
	end

	-- 开火即解除自己的出生保护——玩家一旦行动，无敌就不该继续。
	-- 放在这里而不是 Net.Fire 的接线里：走 resolveShot 的任何路径（含服务器内部调用）都算数。
	SpawnService.breakProtection(shooter)

	-- 方向必须是有效向量：远程事件可以传任何东西
	if typeof(direction) ~= "Vector3" then
		return false
	end
	local magnitude = direction.Magnitude
	if magnitude ~= magnitude or magnitude == 0 then
		return false -- NaN 或零向量
	end
	local unitDirection = direction.Unit

	local origin = shooterOrigin(shooter)
	if not origin then
		return false
	end

	local stamp = now()

	-- 时间戳必须夹在历史窗口内。客户端不能用任意时间戳把别人回溯到有利位置
	-- （比如"回到我瞄准的那个墙角之前"）。非法值退回服务器当前时间。
	local rewindAt = timestamp
	if type(rewindAt) ~= "number" or rewindAt ~= rewindAt then
		rewindAt = stamp
	end
	rewindAt = math.clamp(rewindAt, stamp - HISTORY_MAX_AGE, stamp)

	-- 2. 两道闸（只查不消耗）
	if not WeaponService.canFire(shooter, stamp, weapon) then
		return false
	end

	-- 3. 位置回溯
	local ghosts, ghostInfo = buildGhosts(shooter, origin, rewindAt, weapon.range)

	-- 4. 在快照上做射线
	--
	-- 真实角色**全部排除**，只让射线打回溯出来的临时碰撞盒。
	-- 不这样做的话：回溯偏移接近 0（最常见的正常情况）时，临时盒与真实部件完全重叠，
	-- 射线返回哪个是未定义的——一旦返回真实部件，它在 ghostInfo 里查不到，
	-- 这一枪就会被当成没打中。表现为"偶尔打不中人"，而且不报错。
	local exclude = {}
	if shooter.Character then
		table.insert(exclude, shooter.Character)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= shooter and other.Character then
			table.insert(exclude, other.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, unitDirection * weapon.range, params)

	-- 5. 结算伤害
	local hitPlayer, hitPartName = nil, nil
	if result then
		local info = ghostInfo[result.Instance]
		if info then
			hitPlayer, hitPartName = info.owner, info.partName
		end
	end

	if hitPlayer then
		local targetState = PlayerStateService.get(hitPlayer)
		-- 已死玩家不再结算（Review Focus 第 4 条）；
		-- 出生保护期内命中但掉血被跳过。
		if targetState and targetState.alive and not SpawnService.isProtected(hitPlayer) then
			local newHealth = PlayerStateService.applyDamage(hitPlayer, Damage.compute(weapon, hitPartName))

			-- 服务器的状态是权威的，但要把它推给角色的 Humanoid，
			-- 否则引擎不知道玩家死了——不会触发 Died、不会播死亡表现、也不会重生。
			if newHealth then
				local humanoid = hitPlayer.Character
					and hitPlayer.Character:FindFirstChildWhichIsA("Humanoid")
				if humanoid then
					humanoid.Health = newHealth
				end
			end
		end
	end

	for _, ghost in ipairs(ghosts) do
		ghost:Destroy()
	end

	-- 6. 记账（放行的一枪无论中不中都消耗），并通知射手
	WeaponService.consumeFire(shooter, stamp)

	if result and hitPlayer then
		Net.HitConfirm:FireClient(shooter, result.Position)
	end

	return true
end

return CombatService
