-- 按命中部件计算伤害。
--
-- Head 走武器自己的 headshotMultiplier；其余部件查这张 R6 身体倍率表。
-- R6 的六个部件是 Head / Torso / Left Arm / Right Arm / Left Leg / Right Leg。
--
-- 未知部件必须回退到基础倍率 1，而不是返回 nil——否则扣血会变成 NaN，
-- 玩家血量静默坏掉，而且不报错。改用 R15 或命中装饰物时就会撞上这条路。

local Damage = {}

Damage.PartMultipliers = {
	-- Head 的倍率由 weapon.headshotMultiplier 提供；这里给 1 只是让部件表完整可查。
	Head = 1,
	Torso = 1,
	["Left Arm"] = 0.85,
	["Right Arm"] = 0.85,
	["Left Leg"] = 0.85,
	["Right Leg"] = 0.85,
}

function Damage.compute(weapon, partName)
	if partName == "Head" then
		return weapon.damage * weapon.headshotMultiplier
	end

	local multiplier = Damage.PartMultipliers[partName]
	if type(multiplier) ~= "number" then
		multiplier = 1
	end
	return weapon.damage * multiplier
end

return Damage
