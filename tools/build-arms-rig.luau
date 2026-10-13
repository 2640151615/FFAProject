-- 一次性构建脚本：生成共享的第一人称三段手臂骨架，放进 ReplicatedStorage.ViewModel_Arms
--
-- 为什么是"资产"而不是运行时生成：
--   以后要在 Studio 的动画编辑器里对着这个 rig 做动画，而动画编辑器只能对
--   place 里真实存在的 Model 工作。运行时拼出来的骨架没法被编辑。
--
-- 为什么放在 tools/ 而不是 src/：
--   这是资产构建脚本，不该被 Rojo 同步进 place 当成运行时代码跑。
--
-- 跑法：把本文件内容经 MCP execute_luau 执行一次即可。重复跑会重建。

local RS = game:GetService("ReplicatedStorage")

-- 骨架定义：模型空间，-Z 是前方，+Y 是上，+X 是右
-- 每段用两个关节点描述，部件从一端指向另一端
local UPPER_THICK = 0.36
local FORE_THICK = 0.32
local HAND_SIZE = Vector3.new(0.32, 0.28, 0.36)

-- 关节点位置（模型空间，-Z 前、+Y 上、+X 右）。
--
-- 目标：手落在相机下方约 0.5、前方约 1.2（还要再乘 ViewModel 里的 RIG_SCALE 和位移）。
-- 手压太低会直接掉到屏幕下缘以外——第一版手在相机下方 0.97，结果整个下半屏
-- 只剩一块白色，看不出是手臂。
--
-- 肩关节仍然压得很低：上臂因此落在画面外，第一人称里看到的是两条前臂
-- 从画面底部伸进来，这才是正常的样子。
local ARMS = {
	Right = {
		shoulder = Vector3.new(0.42, -0.62, 0.20),
		elbow = Vector3.new(0.40, -0.55, -0.35),
		wrist = Vector3.new(0.34, -0.45, -0.85),
		handEnd = Vector3.new(0.32, -0.42, -1.05),
	},
	Left = {
		-- 左臂要**横过来够到枪的护木**，不是和右臂对称。
		-- 对称的话左手会落在枪下方，看起来像两只手各拿各的。
		shoulder = Vector3.new(-0.42, -0.62, 0.20),
		elbow = Vector3.new(-0.40, -0.55, -0.35),
		wrist = Vector3.new(0.00, -0.48, -0.95),
		handEnd = Vector3.new(0.22, -0.38, -1.25),
	},
}

local old = RS:FindFirstChild("ViewModel_Arms")
if old then
	old:Destroy()
end

local rig = Instance.new("Model")
rig.Name = "ViewModel_Arms"

-- 根节点：不可见，每帧只 CFrame 它
local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(0.2, 0.2, 0.2)
root.Transparency = 1
root.Anchored = true
root.CanCollide = false
root.CanQuery = false
root.CanTouch = false
root.Parent = rig
rig.PrimaryPart = root

-- 从 from 指向 to 的一段肢体，长轴沿自身的 Z
--
-- 注意：除根节点外，部件**不能锚定**。Motor6D 是靠关节系统驱动部件的，
-- 锚定的部件不会被关节移动。整个骨架因为根节点锚定而成为刚体，
-- 每帧只需要设根节点的 CFrame，其余部件由关节跟随。
local function makeBone(name, from, to, thickness)
	local delta = to - from
	local length = delta.Magnitude
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(thickness, thickness, length)
	part.CFrame = CFrame.lookAt(from + delta * 0.5, to)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = rig
	return part
end

local function makeHand(name, at, towards)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = HAND_SIZE
	part.CFrame = CFrame.lookAt(at, towards)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = rig
	return part
end

-- Motor6D：约束是 Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()
-- 给定期望的两个部件位置 P0 / P1，以及关节在 P0 局部空间的位置 X（即 C0），
-- 反解出 C1 = P1:Inverse() * P0 * X。
-- 把 C0 的旋转留成单位阵，作为动画的基准姿态。
local function makeJoint(name, part0, part1, pivotInWorld)
	local c0 = part0.CFrame:Inverse() * CFrame.new(pivotInWorld)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = part1.CFrame:Inverse() * part0.CFrame * c0
	motor.Parent = part0
	return motor
end

for _, side in ipairs({ "Right", "Left" }) do
	local j = ARMS[side]

	local upper = makeBone(side .. "UpperArm", j.shoulder, j.elbow, UPPER_THICK)
	local fore = makeBone(side .. "Forearm", j.elbow, j.wrist, FORE_THICK)
	local hand = makeHand(side .. "Hand", j.wrist + (j.handEnd - j.wrist) * 0.5, j.handEnd)

	makeJoint(side .. "Shoulder", root, upper, j.shoulder)
	makeJoint(side .. "Elbow", upper, fore, j.elbow)
	makeJoint(side .. "Wrist", fore, hand, j.wrist)
end

-- 动画系统：AnimationController + Animator。
-- 用 AnimationController 而不是 Humanoid —— 这是非人形 rig 的标准做法。
local controller = Instance.new("AnimationController")
controller.Parent = rig

local animator = Instance.new("Animator")
animator.Parent = controller

rig.Parent = RS

local summary = {}
for _, d in ipairs(rig:GetDescendants()) do
	if d:IsA("Motor6D") then
		table.insert(summary, d.Name .. "(" .. d.Part0.Name .. "→" .. d.Part1.Name .. ")")
	end
end

return {
	created = rig.Name,
	parts = (function()
		local t = {}
		for _, c in ipairs(rig:GetChildren()) do
			if c:IsA("BasePart") then table.insert(t, c.Name) end
		end
		return t
	end)(),
	joints = summary,
	hasAnimator = animator ~= nil,
}