# 第一人称视图模型 —— 参数对照表与目录索引

调手臂 / 枪的位置和大小，只需动**三个文件**。

---

## 目录索引

| 文件 | 管什么 | 改完怎么生效 |
|---|---|---|
| [tools/build-arms-rig.luau](../tools/build-arms-rig.luau) | **手臂几何**：粗细、关节点位置 | **重跑构建脚本**（否则被下次同步覆盖）→ 重启 playtest |
| [src/client/ViewModel.luau](../src/client/ViewModel.luau) | **骨架整体**：相对相机的位移与缩放 | 重启 playtest |
| [src/shared/Weapons.luau](../src/shared/Weapons.luau) | **枪**：尺寸、相对右手的位姿（每把枪独立） | Rojo 自动同步 → 重启 playtest |

重跑构建脚本的方法：把 `tools/build-arms-rig.luau` 的内容贴进 Studio **命令栏**（edit 模式下运行）。

---

## 换算公式（最重要的一条）

```
世界偏移 = 模型偏移 × RIG_SCALE
```

当前 `RIG_SCALE = 0.5`，所以**骨架里 1.0 的距离 = 世界上 0.5 studs**。

`ARMS` 表里的坐标都是**模型空间**。忘了这个换算，就会出现"我明明往前推了 1 个单位，怎么只动了一点点"。

**模型空间的轴**：`-Z = 前`、`+Y = 上`、`+X = 右`

---

## A. 手臂几何 —— `tools/build-arms-rig.luau`

### A1. 粗细与尺寸

| 参数 | 当前值 | 管什么 |
|---|---|---|
| `UPPER_THICK` | `0.36` | 上臂粗细（模型空间） |
| `FORE_THICK` | `0.32` | 前臂粗细 |
| `HAND_SIZE` | `Vector3.new(0.32, 0.28, 0.36)` | 手的三边尺寸 |

### A2. 关节点（模型空间）

每段肢体由**两个端点**确定：部件从 `from` 指向 `to`，长度自动算。

| 关节 | 右臂当前值 | 左臂当前值 | 管什么 |
|---|---|---|---|
| `shoulder` | `(0.42, -0.62, 0.20)` | `(-0.42, -0.62, 0.20)` | 肩。**压得低是为了让上臂落在画面外** |
| `elbow` | `(0.40, -0.55, -0.35)` | `(-0.15, -0.62, -0.75)` | 肘 |
| `wrist` | `(0.34, -0.45, -0.85)` | `(0.20, -0.46, -1.50)` | 腕 |
| `handEnd` | `(0.32, -0.42, -1.05)` | `(0.38, -0.38, -1.80)` | 手末端。**决定手的朝向**（`lookAt(wrist→handEnd)`），不是尺寸 |

**两臂不对称是故意的。** 左臂要横过身体够到枪的护木；对称的话左手会落在枪下方，像"两只手各拿各的"。

---

## B. 骨架整体 —— `src/client/ViewModel.luau`

| 参数 | 当前值 | 管什么 | 方向 |
|---|---|---|---|
| `RIG_POSE` | `CFrame.new(0, -0.12, -1.25)` | 骨架根相对**相机**的位移 | 相机局部：`+X` 右、`+Y` 上、`-Z` 前 |
| `RIG_SCALE` | `0.5` | 整套骨架缩放 | 无单位 |

**`RIG_POSE` 的 Z 分量是最有用的旋钮。** 它同时决定"摆在哪"和"离相机多远"，而**屏幕占比与距离成反比**——把 Z 调得更负，手臂和枪会一起变小。

---

## C. 枪 —— `src/shared/Weapons.luau`

每把枪四个字段，其中两个是视图模型相关的：

| 武器 | `viewmodel` | `viewmodelScale` | `viewmodelPose`（相对**右手**） |
|---|---|---|---|
| Rifle | `ViewModel_Rifle` | `0.30` | `CFrame.new(0, 0, 0, -0.0961, 0.9950, -0.0257, -0.1141, 0.0147, 0.9934, 0.9888, 0.0984, 0.1121)` |
| Pistol | `ViewModel_Pistol` | `0.20` | `CFrame.new(-0.0425, 0.0579, -0.0612, -0.0995, 0.9950, 0.0000, 0.1469, 0.0147, 0.9890, 0.9841, 0.0984, -0.1476)` |
| SMG | `ViewModel_Rifle` | `0.14` | 同 Pistol |
| Knife | `ViewModel_Knife` | `0.30` | 同 Pistol |

- **`viewmodelScale`** —— 乘在模型基准尺寸上。步枪基准是 `3.26`，`×0.30` → 世界长度约 `0.98` studs。
- **`viewmodelPose`** —— 就是 `WeaponGrip` 那个 Motor6D 的 `C0`。前三个数是位置，后九个是旋转矩阵。
  - 步枪的位置是 `(0, 0, 0)` = **枪的中心落在右手原点上**（枪是右手的关节孩子，本就该在手上）。

---

## 想要什么效果 → 动哪个

| 想要的效果 | 动哪个 | 怎么动 |
|---|---|---|
| 手臂整体变小 | `RIG_SCALE` | 调小 |
| 手臂和枪一起推向远处 | `RIG_POSE.Z` | 更负 |
| 手臂整体下移 | `RIG_POSE.Y` | 更负 |
| 手臂整体左右移 | `RIG_POSE.X` | 正值右移 |
| 某条手臂的姿势 | `ARMS` 的四个关节点 | 重跑构建脚本 |
| **左手够不够得到护木** | `ARMS.Left.wrist` / `.handEnd` 的 Z | **更负 = 更前** |
| 手臂粗细 | `UPPER_THICK` / `FORE_THICK` | 重跑构建脚本 |
| 枪的大小 | `viewmodelScale` | — |
| 枪相对手的姿态 | `viewmodelPose` | — |

---

## 两条必须记住的耦合

**① 改 `RIG_SCALE` 或任何手臂关节点 → 枪的位置会跟着变。**

因为枪是右手的关节孩子，手一动枪就动。每次都要**重算 `viewmodelPose`**，否则枪会跑偏。

重算方法（在活着的客户端里跑，改完立刻截图）：
```lua
local cam = workspace.CurrentCamera
local rig = cam:FindFirstChild("ViewModel_Arms")
local hand = rig:FindFirstChild("RightHand")
local grip = hand:FindFirstChild("WeaponGrip")

-- 你想要的"枪在相机空间里的位姿"
local desired = cam.CFrame
	* CFrame.new(0.20, -0.44, -1.18)
	* CFrame.Angles(0, math.rad(-90), 0)
	* CFrame.Angles(math.rad(-90), 0, 0)

grip.C0 = hand.CFrame:Inverse() * desired
print(grip.C0:GetComponents())  -- 把结果抄回 Weapons.luau
```

**② 改 `RIG_POSE` 不需要重算 `viewmodelPose`。**

它动的是整体，枪跟着一起走，相对关系不变。

---

## 目标数值与当前状态

| 指标 | 目标 | 当前实测 |
|---|---|---|
| 手臂合计占屏宽 | ≤ 30% | **28%** ✅ |
| 手臂合计占屏高 | ≤ 25% | **25%** ✅ |
| 枪占屏宽 | 30–40% | **41%** ✅（略超） |
| 右手 → 左手 距离 | 0.4–0.5 studs | **0.35** ⚠ 略近 |
| 枪长 | 0.8–1.0 studs | **0.98** ✅ |

---

## 别靠眼睛，量出来

在活着的客户端跑这段，打印**每个部件的真实屏幕包围盒**：

```lua
local cam = workspace.CurrentCamera
local rig = cam:FindFirstChild("ViewModel_Arms")
local vp = cam.ViewportSize

local function footprint(c)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do
		for _, sz in ipairs({-0.5, 0.5}) do
			local sp, ok = cam:WorldToViewportPoint(
				c.CFrame * Vector3.new(c.Size.X*sx, c.Size.Y*sy, c.Size.Z*sz))
			if ok then
				minX = math.min(minX, sp.X); maxX = math.max(maxX, sp.X)
				minY = math.min(minY, sp.Y); maxY = math.max(maxY, sp.Y)
			end
		end
	end end
	if minX == math.huge then return nil end
	return minX, minY, maxX, maxY
end

for _, c in ipairs(rig:GetChildren()) do
	if c:IsA("BasePart") then
		local a, b, cx, d = footprint(c)
		if a then
			print(string.format("%-14s %dx%d px  (%.0f%% 宽 %.0f%% 高)",
				c.Name, cx-a, d-b, (cx-a)/vp.X*100, (d-b)/vp.Y*100))
		else
			print(string.format("%-14s 完全在画面外", c.Name))
		end
	end
end
```

**必须用八个角投影，不能只看部件中心点。** 上臂的中心在相机后方，但它的**边缘探进了画面**——只看中心会被骗，这一点骗了我好几轮。

另一个诊断技巧：**从相机往屏幕上某片区域打射线**。如果 500 studs 内打不到任何世界物体，那块东西就是视图模型自己（射线里排除了 Camera）。

```lua
local ray = cam:ViewportPointToRay(0.3 * vp.X, 0.85 * vp.Y)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { cam }
print(workspace:Raycast(ray.Origin, ray.Direction * 500, params) or "无命中 = 是视图模型")
```

---

## 硬件提醒

`tools/build-arms-rig.luau` 里如果用了 `Motor6D` 的手写缩放，**不要**自己算 `部件尺寸 ×s、C0/C1 位置 ×s`。`C0` 和 `C1` 各自带旋转，`T(a·s)·Ra · (T(b·s)·Rb)⁻¹ ≠ T((a−b)·s)`，位置会偏（实测偏 0.27 studs，表现只是"手臂位置有点怪"，极难归因）。

**用引擎的 `Model:ScaleTo()`。** 现在 `ViewModel.luau` 就是这么做的。
