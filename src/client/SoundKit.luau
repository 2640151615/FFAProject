-- 音效播放的薄封装。
--
-- 为什么要有这一层：`SoundId` 可能是 nil（`Config.KillSound` 就是 nil），
-- 调用方不该到处写 `if id then ... end`。**nil 一律静默无操作，不报错**。
--
-- 两类播放：
--   playLocal  挂 SoundService，无方位。用于自己的开火、UI 反馈。
--   playAt     挂到世界里的部件上，带 3D 衰减。用于别人的动作、脚步——
--              "脚步是战术信息" 就靠这个：远处的脚步自然变轻，近处的清楚。

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SoundKit = {}

-- 声音播完自己销毁；加载失败时 Ended 不会触发，所以再挂一个 Debris 兜底。
local function autoCleanup(sound, fallbackSeconds)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, fallbackSeconds)
end

function SoundKit.playLocal(id, volume)
	if not id then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.Parent = SoundService
	sound:Play()

	autoCleanup(sound, 8)
	return sound
end

-- `part` 是被听到的位置。挂在部件上，引擎自己做距离衰减。
function SoundKit.playAt(id, part, volume, maxDistance)
	if not id or not part then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.8
	sound.RollOffMaxDistance = maxDistance or 140
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = part
	sound:Play()

	autoCleanup(sound, 8)
	return sound
end

return SoundKit
