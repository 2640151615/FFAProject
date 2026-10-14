-- 后坐力曲线。
--
-- 语义：`update(dt)` 返回**本帧应施加给相机的增量**，不是当前累积总量。
--
-- 为什么必须是增量（这条是实测确认的，不要凭直觉改回总量）：
--   `camera.CFrame` **本身就是默认相机脚本的状态源**——鼠标输入是叠加在它上面的。
--   我们每帧改它，它就变成下一帧的基准。如果每帧都施加"总量"，后坐力会复利式累积：
--   实测把 total 写进去后，1.5 秒内俯仰角从 -15° 一路漂到 -12.7°，永远回落不了。
--   施加增量则：衰减时增量变负，相机被拉回原位。
--
-- 用指数衰减而不是线性：线性回落会在到点那一刻"啪"地停住，手感很硬。
--
-- 目前 yaw 是确定值（每发都往同一侧偏）。真实游戏通常加一点随机抖动，
-- 但那样纯函数就没法精确单测了——需要的话给 kick 加一个随机的 yaw 乘数。

local Recoil = {}
Recoil.__index = Recoil

-- 回落速度。越大回得越快。
local DECAY_RATE = 12

function Recoil.new()
	return setmetatable({
		offset = Vector2.new(0, 0), -- 当前累积的后坐力：X 是偏航，Y 是俯仰，单位度
		applied = Vector2.new(0, 0), -- 已经交给相机的那部分
	}, Recoil)
end

-- 每开一枪调用一次。近战武器的两个系数都是 0，所以踢不动相机。
function Recoil:kick(weapon)
	if not weapon then
		return
	end
	self.offset += Vector2.new(weapon.recoilYaw or 0, weapon.recoilPitch or 0)
end

function Recoil:update(dt)
	self.offset = self.offset * math.exp(-DECAY_RATE * dt)

	local delta = self.offset - self.applied
	self.applied = self.offset
	return delta
end

-- 立刻清零，并且让下一帧的增量也是零——否则相机会因为"欠账"被反向拽一次。
function Recoil:reset()
	self.offset = Vector2.new(0, 0)
	self.applied = Vector2.new(0, 0)
end

return Recoil
