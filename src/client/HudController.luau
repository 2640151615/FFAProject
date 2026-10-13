-- HUD：准星、血量、命中标记。
--
-- 竞技向的准星是**静态四段式**，不用动态扩散准星——扩散准星会把"当前精度"
-- 这条信息喂给玩家，而我们的设计里首发必准、扩散只在连发时累积，
-- 让准星去表达它反而会误导。
--
-- 移动端布局从简：Roblox 的动态摇杆在左下，跳跃键在右下，
-- 所以准星居中、血量条放**底部中央**，两边都不挡。
-- 弹药（M4）和记分板（M5）之后接在这里。
--
-- 命中标记来自服务器的 HitConfirm——命中判定完全由服务器裁决，
-- 客户端不自己判断有没有打中。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Net = require(ReplicatedStorage:WaitForChild("Net"))

local HudController = {}

local player = Players.LocalPlayer

local HITMARKER_TIME = 0.12

local screenGui = nil
local hitmarker = nil
local healthFill = nil
local healthLabel = nil
local hitmarkerToken = 0

-- 暗色描边：准星和标记必须在一块白墙和一块黑地上都看得见
local function withOutline(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.45
	stroke.Parent = parent
	return parent
end

local function makeFrame(name, size, position, anchor, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- 四段式准星：上下左右各一根短条，中间留空
local function buildCrosshair(parent)
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.BackgroundTransparency = 1
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(0, 0)
	crosshair.Parent = parent

	local ARM = 9
	local THICK = 2
	local GAP = 5

	local arms = {
		{ UDim2.fromOffset(THICK, ARM), UDim2.new(0.5, -THICK / 2, 0.5, -(GAP + ARM)) },
		{ UDim2.fromOffset(THICK, ARM), UDim2.new(0.5, -THICK / 2, 0.5, GAP) },
		{ UDim2.fromOffset(ARM, THICK), UDim2.new(0.5, -(GAP + ARM), 0.5, -THICK / 2) },
		{ UDim2.fromOffset(ARM, THICK), UDim2.new(0.5, GAP, 0.5, -THICK / 2) },
	}

	for index, arm in ipairs(arms) do
		local bar = makeFrame("Arm" .. index, arm[1], arm[2], Vector2.new(0, 0), crosshair)
		withOutline(bar)
	end

	return crosshair
end

-- 命中标记：四条斜线，打中时闪一下
local function buildHitmarker(parent)
	local marker = Instance.new("Frame")
	marker.Name = "Hitmarker"
	marker.BackgroundTransparency = 1
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.fromOffset(0, 0)
	marker.Visible = false
	marker.Parent = parent

	local LENGTH = 8
	local THICK = 2
	local OFFSET = 4

	local diagonals = {
		{ OFFSET, OFFSET, 45 },
		{ -OFFSET, OFFSET, -45 },
		{ OFFSET, -OFFSET, -45 },
		{ -OFFSET, -OFFSET, 45 },
	}

	for index, spec in ipairs(diagonals) do
		local bar = makeFrame(
			"Tick" .. index,
			UDim2.fromOffset(THICK, LENGTH),
			UDim2.new(0.5, spec[1] - THICK / 2, 0.5, spec[2] - LENGTH / 2),
			Vector2.new(0, 0),
			marker
		)
		bar.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
		bar.Rotation = spec[3]
		withOutline(bar)
	end

	return marker
end

-- 血量条 + 数字。放底部中央，避开左下的摇杆和右下的跳跃键。
local function buildHealth(parent)
	local holder = Instance.new("Frame")
	holder.Name = "Health"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -24)
	holder.Size = UDim2.fromOffset(220, 20)
	holder.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = holder

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 210, 120)
	fill.BorderSizePixel = 0
	fill.Parent = holder

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = "100"
	label.Parent = holder

	return fill, label
end

local function flashHitmarker()
	hitmarkerToken += 1
	local token = hitmarkerToken

	hitmarker.Visible = true
	task.delay(HITMARKER_TIME, function()
		-- 连续命中时，后一次不该被前一帧的定时器提前关掉
		if token == hitmarkerToken then
			hitmarker.Visible = false
		end
	end)
end

local function setHealth(health, maxHealth)
	local ratio = 0
	if maxHealth and maxHealth > 0 then
		ratio = math.clamp(health / maxHealth, 0, 1)
	end

	if healthFill then
		healthFill.Size = UDim2.fromScale(ratio, 1)
		-- 低血变红，给一个不用读数字就能察觉的信号
		healthFill.BackgroundColor3 = Color3.fromRGB(90, 210, 120):Lerp(
			Color3.fromRGB(220, 70, 70),
			1 - ratio
		)
	end
	if healthLabel then
		healthLabel.Text = tostring(math.max(0, math.floor(health + 0.5)))
	end
end

local function watchHumanoid(character)
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	setHealth(humanoid.Health, humanoid.MaxHealth)
	humanoid.HealthChanged:Connect(function(health)
		setHealth(health, humanoid.MaxHealth)
	end)
end

function HudController.init()
	if screenGui then
		return
	end

	-- 关掉引擎自带的血条。
	--
	-- 注意别和 `Humanoid.HealthDisplayType` 搞混，那是两样不同的东西：
	--   · 这一条关的是 **CoreGui 的 Health 组件**——右上角那个、受伤时才冒出来的屏幕 UI。
	--   · `Humanoid.HealthDisplayType` 管的是 **角色头顶那个 3D 血条**，在 SpawnService 里设成 AlwaysOff。
	-- 两个都要关，否则各冒各的。
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FFA_Hud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = player:WaitForChild("PlayerGui")

	buildCrosshair(screenGui)
	hitmarker = buildHitmarker(screenGui)
	healthFill, healthLabel = buildHealth(screenGui)

	Net.HitConfirm.OnClientEvent:Connect(flashHitmarker)

	if player.Character then
		watchHumanoid(player.Character)
	end
	player.CharacterAdded:Connect(watchHumanoid)
end

return HudController
