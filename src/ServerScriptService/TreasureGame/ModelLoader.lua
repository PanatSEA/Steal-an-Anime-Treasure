-- ModelLoader: loads boss and character models by name from ReplicatedStorage.Models.
--   Models/Bosses/<BossId>                     (needs a Humanoid + HumanoidRootPart)
--   Models/Characters/<SeriesId>/<CharacterId>
-- A missing model becomes a grey dummy; callers add the name label.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local World = AnimeConfig.World

local ModelLoader = {}

local GREY = Color3.fromRGB(163, 162, 165)
local BODY_COLOR_KEYS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }

local function findModel(path)
	local node = ReplicatedStorage
	for _, name in ipairs(path) do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("Model") then
		return node
	end
	return nil
end

local function greyDummy(name, scale)
	local description = Instance.new("HumanoidDescription")
	for _, key in ipairs(BODY_COLOR_KEYS) do
		description[key] = GREY
	end
	description.HeightScale = scale
	description.WidthScale = scale
	description.DepthScale = scale
	description.HeadScale = scale
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	return model
end

-- Returns a fresh boss model. TODO: art comes from Models/Bosses/<BossId>.
function ModelLoader.Boss(bossId)
	local source = findModel({ World.ModelsFolderName, World.BossModelsFolderName, bossId })
	if source then
		if source:FindFirstChildOfClass("Humanoid") and source:FindFirstChild("HumanoidRootPart") then
			local model = source:Clone()
			model.Name = bossId
			model.PrimaryPart = model.HumanoidRootPart
			return model
		end
		warn(("[TreasureGame] Models/Bosses/%s needs a Humanoid and HumanoidRootPart; using grey-box"):format(bossId))
	end
	return greyDummy(bossId, 1.4)
end

-- Returns a fresh, anchored character model for display on a plot.
function ModelLoader.Character(seriesId, characterId)
	local source = findModel({ World.ModelsFolderName, World.CharacterModelsFolderName, seriesId, characterId })
	local model = source and source:Clone() or greyDummy(characterId, 1)
	model.Name = characterId
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return model
end

return ModelLoader
