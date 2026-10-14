-- 服务器位置回溯（延迟补偿）。
--
-- 射手的 Fire 请求带一个时间戳；服务器要把其他玩家回溯到"开火那一刻"的位置再判定，
-- 否则高延迟和移动端玩家永远打不中人——这直接违反"枪法好的人赢，不是网络好的人赢"。
--
-- 每个 key（玩家）一条按时间升序的记录。record 时顺手丢弃窗口外的旧点；
-- sample **只读**，不改变任何状态——幂等性是有测试钉住的，改坏了会被抓到。

local LagCompensation = {}
LagCompensation.__index = LagCompensation

function LagCompensation.new(maxAge)
	return setmetatable({
		maxAge = maxAge,
		history = {},
	}, LagCompensation)
end

-- 假定调用方按时间升序传入。真实的每帧采样天然满足这一条。
function LagCompensation:record(key, position, now)
	local list = self.history[key]
	if not list then
		list = {}
		self.history[key] = list
	end

	table.insert(list, { t = now, p = position })

	local cutoff = now - self.maxAge
	while #list > 0 and list[1].t < cutoff do
		table.remove(list, 1)
	end
end

function LagCompensation:sample(key, timestamp)
	local list = self.history[key]
	if not list or #list == 0 then
		return nil
	end

	-- 早于窗口（最老的点都比它新）——无从回溯
	if timestamp < list[1].t then
		return nil
	end

	-- 比最新记录还新：直接给最新位置
	if timestamp >= list[#list].t then
		return list[#list].p
	end

	for i = 1, #list - 1 do
		local a, b = list[i], list[i + 1]
		if timestamp >= a.t and timestamp <= b.t then
			local span = b.t - a.t
			if span <= 0 then
				return b.p
			end
			return a.p:Lerp(b.p, (timestamp - a.t) / span)
		end
	end

	return list[#list].p
end

return LagCompensation
