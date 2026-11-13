-- Carry: placeholder treasure part + welding it above a character's head.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))

local Carry = {}

local TREASURE_SIZE = Vector3.new(2.4, 1.8, 1.8)
local TREASURE_COLOR = Color3.fromRGB(255, 200, 40)

-- Placeholder until TreasureModelName has a real model.
-- rarityName is the chest rarity rolled at dig time (falls back to the boss tier).
function Carry.MakeTreasure(cfg, rarityName)
	rarityName = rarityName or cfg.Rarity
	local rarity = AnimeConfig.Rarities[rarityName]

	local part = Instance.new("Part")
	part.Name = "Treasure_" .. cfg.BossId
	part.Size = TREASURE_SIZE
	part.Material = Enum.Material.Neon
	part.Color = TREASURE_COLOR
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = rarity.Color
	highlight.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 24)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 120
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rarity.Color
	label.TextStrokeTransparency = 0.3
	label.Text = ("%s [%s]"):format(cfg.TreasureName, rarityName)
	label.Parent = billboard

	return part
end

-- Welds the treasure above the character's head. Returns false if there is no head.
function Carry.AttachToCharacter(character, treasure)
	local head = character:FindFirstChild("Head")
	if not head then
		return false
	end
	treasure.Anchored = false
	treasure.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + treasure.Size.Y / 2 + 1, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = treasure
	weld.Parent = treasure

	treasure.Parent = character
	return true
end

return Carry
