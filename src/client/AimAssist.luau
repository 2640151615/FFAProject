-- 触屏弱辅助瞄准。
--
-- **这个模块存在的风险不是"没效果"，而是"效果太强"。**
-- 设计文档的反目标写死了"不要变成自动瞄准大战"，所以这个实现里有一条硬约束：
-- 无论传入多强的 strength、无论目标偏多远，偏转角**永远被夹在 maxAngleDegrees 内**。
-- 那条 clamp 不是防御性代码，它就是规格本身——测试里几条用例专门钉它。
--
-- 正确形态是"手指差一点点也能打中"，不是"不用瞄也能打中"。
--
-- 纯函数：不碰相机、不查场景，只吃方向 + 候选方向。候选由调用方提供
-- （哪个玩家可见、在不在射程内，是调用方的事）。

local AimAssist = {}
AimAssist.__index = AimAssist

-- 开镜时的强度倍率。开镜本来就更准，辅助再给满等于双重优惠。
local ADS_FACTOR = 0.35

function AimAssist.new(maxAngleDegrees, strength)
	return setmetatable({
		maxAngle = maxAngleDegrees,
		strength = strength,
	}, AimAssist)
end

local function angleBetween(a, b)
	return math.acos(math.clamp(a:Dot(b), -1, 1))
end

-- 找出偏离最小的候选。nil 与零向量直接跳过——调用方很容易塞进脏数据。
local function nearestCandidate(aim, candidates)
	local best, bestAngle = nil, math.huge

	for _, candidate in ipairs(candidates) do
		if typeof(candidate) == "Vector3" and candidate.Magnitude > 1e-6 then
			local unit = candidate.Unit
			local angle = angleBetween(aim, unit)
			if angle < bestAngle then
				best, bestAngle = unit, angle
			end
		end
	end

	return best, bestAngle
end

function AimAssist:apply(aimDirection, candidates, isAiming)
	local aim = aimDirection.Unit
	local best, bestAngle = nearestCandidate(aim, candidates)

	if not best then
		return aim
	end

	local strength = self.strength
	if isAiming then
		strength = strength * ADS_FACTOR
	end

	-- 偏转量 = 上限 × 强度，且**硬夹在上限内**。第二道 min 是防止转过头。
	local maxTurn = math.rad(self.maxAngle)
	local turn = math.min(maxTurn * strength, maxTurn)
	turn = math.min(turn, bestAngle)

	if turn <= 0 then
		return aim
	end

	local axis = aim:Cross(best)
	if axis.Magnitude < 1e-6 then
		-- 与目标平行：同向时无需偏转；完全反向时没有唯一的旋转轴，
		-- 硬选一个轴会随机把视角甩向一侧——不如不动。
		return aim
	end

	return (CFrame.fromAxisAngle(axis.Unit, turn) * aim).Unit
end

return AimAssist
