-- 纯第一人称：锁定相机，并把自己的角色部件在本地隐藏。
--
-- 隐藏必须每帧重设：引擎会在第一人称下自行调整部分部件的 LocalTransparencyModifier，
-- 一次性设置压不住。竞技向里"看得到自己的身体"等于多一份信息，不能让它漏出来。
--
-- R6 只有六个部件，每帧遍历的开销可以忽略；部件列表在每次重生时重建。

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FirstPerson = {}

local player = Players.LocalPlayer

local trackedParts = {}

local function rebuild(character)
	trackedParts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(trackedParts, descendant)
		end
	end
end

function FirstPerson.lock()
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	local function onCharacter(character)
		rebuild(character)
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				table.insert(trackedParts, descendant)
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	RunService.RenderStepped:Connect(function()
		for _, part in ipairs(trackedParts) do
			part.LocalTransparencyModifier = 1
		end
	end)
end

return FirstPerson
