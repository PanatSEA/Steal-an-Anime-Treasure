-- Carry: the treasure chest a player carries, and the chests shown on plots.
-- Uses ReplicatedStorage/Models/Treasures/Chest (see TreasureModels). Rarity is shown with
-- a glow (halo, light, aura), not by repainting the model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local HeldPhysics = require(script.Parent.HeldPhysics)

local Carry = {}

local LABEL_NAME = "TreasureLabel"
local HEAD_GAP = 0.6 -- studs between the head and the bottom of the carried chest
local LABEL_GAP = 0.9 -- studs between the top of the chest and its name label

-- Returns a chest model with a rarity glow and a name label.
-- rarityName falls back to the boss tier. opts.Scale (default 1, relative to the model's
-- own size); opts.Anchored = true for display chests, false (default) to carry.
function Carry.MakeTreasure(cfg, rarityName, opts)
	opts = opts or {}
	rarityName = rarityName or cfg.Rarity
	local rarity = AnimeConfig.Rarities[rarityName]
	local anchored = opts.Anchored == true

	local model = TreasureModels.Chest()
	model.Name = "Treasure_" .. cfg.BossId
	if opts.Scale and opts.Scale ~= 1 then
		model:ScaleTo(model:GetScale() * opts.Scale)
	end
	TreasureModels.ApplyRarityGlow(model, rarityName, anchored)

	TreasureModels.SetDecorative(model, anchored)
	local root = model.PrimaryPart
	if not anchored then
		HeldPhysics.Apply(model, root, false) -- carried: must never push the carrier around
	end

	-- Label just above the top of the chest, whatever the model's root/pivot layout.
	local pivot = model:GetPivot()
	local topAbovePivot = TreasureModels.Height(model) - TreasureModels.PivotHeight(model)
	local rootAbovePivot = pivot:PointToObjectSpace(root.Position).Y

	local billboard = Instance.new("BillboardGui")
	billboard.Name = LABEL_NAME
	billboard.Size = UDim2.fromOffset(200, 24)
	billboard.StudsOffset = Vector3.new(0, topAbovePivot - rootAbovePivot + LABEL_GAP, 0)
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
	local pivotHeight = TreasureModels.PivotHeight(treasure)
	treasure:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + HEAD_GAP + pivotHeight, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = root
	weld.Parent = root

	treasure.Parent = character
	return true
end

return Carry
