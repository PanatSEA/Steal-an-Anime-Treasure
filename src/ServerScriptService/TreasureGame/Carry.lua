-- Carry: the treasure chest a player carries, and the chests shown on plots.
-- Uses ReplicatedStorage/Models/Treasures/Chest (see TreasureModels), tinted by rarity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local HeldPhysics = require(script.Parent.HeldPhysics)

local Carry = {}

local LABEL_NAME = "TreasureLabel"
local HEAD_GAP = 0.6 -- studs between the head and the bottom of the carried chest

-- Returns a chest model tinted to rarityName (falls back to the boss tier) with a name label.
-- opts.Scale (default 1); opts.Anchored = true for display chests, false (default) to carry.
function Carry.MakeTreasure(cfg, rarityName, opts)
	opts = opts or {}
	rarityName = rarityName or cfg.Rarity
	local rarity = AnimeConfig.Rarities[rarityName]

	local model = TreasureModels.Chest()
	model.Name = "Treasure_" .. cfg.BossId
	if opts.Scale and opts.Scale ~= 1 then
		model:ScaleTo(opts.Scale)
	end
	TreasureModels.ApplyRarity(model, rarityName)

	local anchored = opts.Anchored == true
	TreasureModels.SetDecorative(model, anchored)
	local root = model.PrimaryPart
	if not anchored then
		HeldPhysics.Apply(model, root, false) -- carried: must never push the carrier around
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = LABEL_NAME
	billboard.Size = UDim2.fromOffset(200, 24)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 120
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rarity.Color
	label.TextStrokeTransparency = 0.3
	label.Text = ("%s [%s]"):format(cfg.TreasureName, rarityName)
	label.Parent = billboard

	return model
end

function Carry.GetLabel(model)
	local billboard = model.PrimaryPart and model.PrimaryPart:FindFirstChild(LABEL_NAME)
	return billboard and billboard:FindFirstChildOfClass("TextLabel")
end

-- Welds the chest above the character's head. Returns false if there is no head.
function Carry.AttachToCharacter(character, treasure)
	local head = character:FindFirstChild("Head")
	if not head then
		return false
	end
	local root = treasure.PrimaryPart
	treasure:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + HEAD_GAP + root.Size.Y / 2, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = root
	weld.Parent = root

	treasure.Parent = character
	return true
end

return Carry
