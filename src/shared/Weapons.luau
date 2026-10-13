-- 武器定义表。加一把枪 = 加一条表项，逻辑代码不用动。
-- WeaponService 只从这里读数值，且从不相信任何从网络传来的数字。
--
-- damage / fireRate / magazineSize / range 是服务器掌管的平衡数据。
-- 客户端读同一张表来镜像射速、后坐力与 HUD 数值。
--
-- `kind` 决定服务器走哪条开火路径：
--   "ranged" 单发射线，消耗弹药、会换弹。
--   "melee"  短距离球扫，无弹药、不换弹。
--
-- 表现层字段（纯客户端展示）：
--   viewmodel        ReplicatedStorage 里已存在的 Model 名，不是 asset id——
--                    运行时动态加载资产是受限的。客户端把它克隆到 Camera 上。
--   viewmodelScale   统一缩放，因为源模型是世界尺寸的。
--   viewmodelPose    相机空间下的静止 CFrame。
-- 音效就是普通 asset id，由客户端播放。

local Weapons = {}

Weapons.Default = "Rifle"

-- 有序槽位表。下标就是玩家按下的数字键，所以客户端和服务器
-- 不需要第二张查表就能对齐槽位。
Weapons.Slots = { "Rifle", "Pistol", "SMG", "Knife" }

Weapons.Definitions = {
	Rifle = {
		displayName = "Rifle",
		kind = "ranged",
		damage = 24,
		headshotMultiplier = 1.8,
		fireRate = 600, -- 发/分
		automatic = true,
		magazineSize = 30,
		reloadTime = 2.2,
		range = 300,
		-- 后坐力，单位为度，每发踢入相机。
		recoilPitch = 0.5,
		recoilYaw = 0.22,
		-- 竞技向：首发必准，扩散只在连发时累积。
		firstShotSpread = 0,
		viewmodel = "ViewModel_Rifle",
		-- ⚠ 当前是**暂停时的中间状态，不是完成品**。见台账 Task 9。
		-- 位置全零 = 枪的中心落在右手原点上；这个旋转把枪管对到前方。
		viewmodelScale = 0.45,
		-- 相对**右手**的握持位姿（不是相对相机）。
		-- 位置为零：枪的中心落在右手原点。换手臂姿势要重调（枪是手的关节孩子）。
		viewmodelPose = CFrame.new(0.0000, 0.0000, 0.0000, -0.0961, 0.9950, -0.0257, -0.1141, 0.0147, 0.9934, 0.9888, 0.0984, 0.1121),
		fireSound = "rbxassetid://2047319236",
		reloadSound = "rbxassetid://124349595603622",
	},

	Pistol = {
		displayName = "Pistol",
		kind = "ranged",
		damage = 34,
		headshotMultiplier = 2,
		fireRate = 300,
		automatic = false,
		magazineSize = 12,
		reloadTime = 1.5,
		range = 220,
		recoilPitch = 1.1,
		recoilYaw = 0.3,
		firstShotSpread = 0,
		viewmodel = "ViewModel_Pistol",
		viewmodelScale = 0.20,
		-- 和步枪共用同一个"相对右手"的位姿，只是缩放不同。
		-- 三把武器都是单部件模型，形状差异靠缩放和后续微调吸收。
		viewmodelPose = CFrame.new(-0.0425, 0.0579, -0.0612, -0.0995, 0.9950, 0.0000, 0.1469, 0.0147, 0.9890, 0.9841, 0.0984, -0.1476),
		fireSound = "rbxassetid://143286342",
		reloadSound = "rbxassetid://174295321",
	},

	SMG = {
		displayName = "SMG",
		kind = "ranged",
		damage = 15,
		headshotMultiplier = 1.5,
		fireRate = 900,
		automatic = true,
		magazineSize = 35,
		reloadTime = 2,
		range = 180,
		recoilPitch = 0.32,
		recoilYaw = 0.3,
		firstShotSpread = 0,
		-- 暂时借用步枪模型，等有正经的 SMG 模型再换。
		viewmodel = "ViewModel_Rifle",
		viewmodelScale = 0.14,
		viewmodelPose = CFrame.new(-0.0425, 0.0579, -0.0612, -0.0995, 0.9950, 0.0000, 0.1469, 0.0147, 0.9890, 0.9841, 0.0984, -0.1476),
		fireSound = "rbxassetid://2047319236",
		reloadSound = "rbxassetid://124349595603622",
	},

	Knife = {
		displayName = "Knife",
		kind = "melee",
		damage = 55,
		-- 挥砍没有头可打，倍率刻意取中性值。
		headshotMultiplier = 1,
		fireRate = 120, -- 挥/分，即 0.5 秒一刀
		automatic = false,
		magazineSize = nil,
		reloadTime = nil,
		range = 8,
		-- 球扫半径：刀不该要求像素级瞄准。
		swingRadius = 1.2,
		recoilPitch = 0,
		recoilYaw = 0,
		firstShotSpread = 0,
		viewmodel = "ViewModel_Knife",
		viewmodelScale = 0.30,
		viewmodelPose = CFrame.new(-0.0425, 0.0579, -0.0612, -0.0995, 0.9950, 0.0000, 0.1469, 0.0147, 0.9890, 0.9841, 0.0984, -0.1476),
		fireSound = "rbxassetid://153647529",
		reloadSound = nil,
	},
}

function Weapons.get(weaponId)
	if type(weaponId) ~= "string" then
		return nil
	end
	return Weapons.Definitions[weaponId]
end

function Weapons.forSlot(slot)
	if type(slot) ~= "number" then
		return nil
	end
	return Weapons.Slots[slot]
end

-- 武器是否带弹匣。调用方据此分支，不必到处重复 kind 判断。
function Weapons.usesAmmo(weapon)
	return weapon ~= nil and weapon.kind == "ranged"
end

return Weapons
