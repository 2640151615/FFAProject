-- 共享常量。服务器和客户端都读，所以这里不能放敏感信息
-- （伤害、弹药数、命中结果永远不进这里）。

local Config = {}

Config.RespawnDelay = 3
Config.ScoreLimit = 30
Config.MaxPlayers = 12

-- 出生保护：短暂无敌，开火或移动即失效（见 SpawnService.breakProtection）。
Config.SpawnProtectionTime = 2

-- 每名玩家的 Fire 请求上限，在任何武器相关校验之前先行应用。
-- 突发额度足够吸收延迟抖动，又不至于让客户端刷爆远程事件。
Config.MaxRequestsPerSecond = 20
Config.RequestBurst = 40

-- 资产槽位。nil 是静默无操作，不是错误。
Config.HitmarkerSound = "rbxassetid://160432334"
Config.KillSound = nil

-- 触屏弱辅助瞄准。
--
-- `AimAssistMaxAngle` 是**硬上限**，不是建议值：无论目标偏多远、强度设多大，
-- 偏转角都被夹在它之内。调大这个数就等于把游戏推向"自动跟枪"，
-- 而那正是设计文档写死的反目标。想改的话先回去读一遍反目标那节。
Config.AimAssistMaxAngle = 3
Config.AimAssistStrength = 1
Config.AimAssistRange = 120

return Config
