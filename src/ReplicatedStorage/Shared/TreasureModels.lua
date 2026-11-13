-- TreasureModels: the chest and dirt mound, loaded by name (used by server and client).
--   ReplicatedStorage/Models/Treasures/Chest
--       Your own chest model (prepare it with tools/PrepareChestModel.luau): PrimaryPart
--       with its pivot at the bottom centre, front (lock side) facing -Z. An optional Model
--       "Lid" whose PrimaryPart sits on the back hinge gives a lid-opening animation;
--       without one, chests open with a burst.
--   ReplicatedStorage/Models/Treasures/DirtMound
--       PrimaryPart "Root" at ground level; parts named "Chunk" or "Crystal" break off on hits.
-- If a model is missing, a part-built placeholder is used instead (the old chest, with a lid).
-- Rarity is shown with a glow (soft glow sprite + light + sparkle aura), never by repainting the model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AnimeConfig = require(script.Parent:WaitForChild("AnimeConfig"))
local World = AnimeConfig.World

local TreasureModels = {}

TreasureModels.RAINBOW_TAG = "RainbowGlow" -- clients cycle the colour of tagged glow pieces
TreasureModels.GLOW_NAME = "RarityGlow"

local GLOW_COLORS = {
	Common = Color3.fromRGB(255, 255, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Secret = Color3.fromRGB(255, 60, 60), -- start colour; it cycles through the rainbow
}
local RAINBOW = { Secret = true }

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local GLOW_TEXTURE = "rbxassetid://109223850052778" -- soft glow disc from the PBlue VFX pack ("ring")

local function source(name)
	local models = ReplicatedStorage:FindFirstChild(World.ModelsFolderName)
	local folder = models and models:FindFirstChild(World.TreasureModelsFolderName)
	local model = folder and folder:FindFirstChild(name)
	if model and model:IsA("Model") and model.PrimaryPart then
		return model
	end
	return nil
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- The old part-built chest (wood, metal trim, gold lock, moss, hinged lid).
local function fallbackChest()
	local WOOD = Color3.fromRGB(150, 95, 55)
	local WOOD_LIGHT = Color3.fromRGB(170, 110, 62)
	local WOOD_DARK = Color3.fromRGB(110, 68, 38)
	local METAL = Color3.fromRGB(85, 85, 95)
	local GOLD = Color3.fromRGB(255, 200, 60)
	local MOSS = Color3.fromRGB(95, 160, 65)
	local METAL_MAT = Enum.Material.Metal

	local chest = Instance.new("Model")
	chest.Name = "Chest"
	local base = part({ Name = "Base", Size = Vector3.new(3.2, 1.6, 2.2), CFrame = CFrame.new(0, 0.8, 0), Color = WOOD, Parent = chest })
	for _, y in ipairs({ 0.55, 1.1 }) do
		part({ Name = "Plank", Size = Vector3.new(3.22, 0.07, 2.22), CFrame = CFrame.new(0, y, 0), Color = WOOD_DARK, Parent = chest })
	end
	for _, x in ipairs({ -1.05, 1.05 }) do
		part({ Name = "Trim", Size = Vector3.new(0.28, 1.64, 2.26), CFrame = CFrame.new(x, 0.8, 0), Color = METAL, Material = METAL_MAT, Parent = chest })
	end
	part({ Name = "Trim", Size = Vector3.new(3.26, 0.22, 2.26), CFrame = CFrame.new(0, 0.11, 0), Color = METAL, Material = METAL_MAT, Parent = chest })
	part({ Name = "Lock", Size = Vector3.new(0.55, 0.65, 0.15), CFrame = CFrame.new(0, 1.5, -1.17), Color = GOLD, Material = METAL_MAT, Parent = chest })
	part({ Name = "Keyhole", Size = Vector3.new(0.12, 0.22, 0.05), CFrame = CFrame.new(0, 1.45, -1.25), Color = Color3.fromRGB(30, 25, 20), Parent = chest })
	part({ Name = "Moss", Size = Vector3.new(0.14, 0.6, 0.9), CFrame = CFrame.new(1.67, 0.42, 0.4), Color = MOSS, Parent = chest })

	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = chest
	local hinge = part({ Name = "LidHinge", Size = Vector3.new(3.3, 0.1, 0.1), CFrame = CFrame.new(0, 1.6, 1.15), Transparency = 1, Parent = lid })
	part({ Name = "LidTop", Size = Vector3.new(3.3, 0.75, 2.3), CFrame = CFrame.new(0, 1.975, 0), Color = WOOD_LIGHT, Parent = lid })
	part({ Name = "LidPlank", Size = Vector3.new(3.32, 0.07, 2.32), CFrame = CFrame.new(0, 2.15, 0), Color = WOOD_DARK, Parent = lid })
	for _, x in ipairs({ -1.05, 1.05 }) do
		part({ Name = "Trim", Size = Vector3.new(0.3, 0.79, 2.34), CFrame = CFrame.new(x, 1.975, 0), Color = METAL, Material = METAL_MAT, Parent = lid })
	end
	part({ Name = "Moss", Size = Vector3.new(1.0, 0.12, 0.8), CFrame = CFrame.new(-0.55, 2.41, 0.35), Color = MOSS, Parent = lid })
	part({ Name = "Moss", Size = Vector3.new(0.6, 0.1, 0.5), CFrame = CFrame.new(0.5, 2.4, -0.55), Color = MOSS, Parent = lid })
	lid.PrimaryPart = hinge

	chest.PrimaryPart = base
	return chest
end

local function fallbackMound()
	local model = Instance.new("Model")
	model.Name = "DirtMound"
	local root = part({ Name = "Root", Size = Vector3.new(8, 0.2, 8), CFrame = CFrame.new(0, 0.1, 0), Transparency = 1, Parent = model })
	local body = part({ Name = "Body", Size = Vector3.new(8, 3, 8), CFrame = CFrame.new(0, 0, 0), Color = Color3.fromRGB(120, 78, 45), Parent = model })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	model.PrimaryPart = root
	return model
end

function TreasureModels.Chest()
	local found = source("Chest")
	return found and found:Clone() or fallbackChest()
end

function TreasureModels.DirtMound()
	local found = source("DirtMound")
	return found and found:Clone() or fallbackMound()
end

-- The lid model (PrimaryPart on the back hinge), or nil for single-mesh chests.
function TreasureModels.GetLid(model)
	local lid = model:FindFirstChild("Lid")
	if lid and lid:IsA("Model") and lid.PrimaryPart then
		return lid
	end
	return nil
end

-- Distance from the model's pivot down to its lowest point (0 when the pivot is at the bottom).
-- Measured in the pivot's own frame, so it also works while the chest is tilted.
function TreasureModels.PivotHeight(model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local centre = model:GetPivot():PointToObjectSpace(boxCFrame.Position)
	return boxSize.Y / 2 - centre.Y
end

function TreasureModels.Height(model)
	local _, boxSize = model:GetBoundingBox()
	return boxSize.Y
end

function TreasureModels.GlowColor(rarityName)
	return GLOW_COLORS[rarityName] or GLOW_COLORS.Common
end

function TreasureModels.IsRainbow(rarityName)
	return RAINBOW[rarityName] == true
end

-- Rainbow keypoints for particle bursts (Secret).
function TreasureModels.RainbowSequence()
	local points = {}
	for i = 0, 6 do
		table.insert(points, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.9, 1)))
	end
	return ColorSequence.new(points)
end

-- Adds a rarity glow without touching the model's own colours: a soft glow sprite behind
-- the chest, a light and a slow sparkle aura (no parts, so it never affects physics).
-- Secret is tagged so clients cycle it through the rainbow. `anchored` is kept for callers
-- of the old part-based halo and is no longer needed.
function TreasureModels.ApplyRarityGlow(model, rarityName, _anchored)
	local root = model.PrimaryPart
	local oldGlow = model:FindFirstChild(TreasureModels.GLOW_NAME)
	if oldGlow then
		oldGlow:Destroy()
	end
	local oldAttachment = root:FindFirstChild("GlowAttachment")
	if oldAttachment then
		oldAttachment:Destroy()
	end
	if not rarityName then
		return
	end
	local color = TreasureModels.GlowColor(rarityName)
	local rainbow = TreasureModels.IsRainbow(rarityName)
	local boxCFrame, boxSize = model:GetBoundingBox()

	-- A little above the chest's centre, so the ground doesn't cut the bottom of the glow.
	local attachment = Instance.new("Attachment")
	attachment.Name = "GlowAttachment"
	attachment.Parent = root
	attachment.WorldPosition = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.3, 0)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.max(boxSize.X, boxSize.Y) * 3
	light.Brightness = 2.5
	light.Parent = attachment

	local aura = Instance.new("ParticleEmitter")
	aura.Texture = SPARKLE_TEXTURE
	aura.Color = ColorSequence.new(color)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Rate = rainbow and 10 or 5
	aura.Speed = NumberRange.new(0.5, 1.5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = attachment

	-- Soft glow behind the chest (pushed back towards the camera's far side by ZOffset). Mostly
	-- normal blending so the colour still shows on bright sand.
	local glowSize = math.max(boxSize.X, boxSize.Y) * 1.8
	local glow = Instance.new("ParticleEmitter")
	glow.Name = "GlowSprite"
	glow.Texture = GLOW_TEXTURE
	glow.Color = ColorSequence.new(color)
	glow.LightEmission = 0.3
	glow.LightInfluence = 0
	glow.Brightness = 1.5
	glow.Size = NumberSequence.new(glowSize)
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.Lifetime = NumberRange.new(1.2, 1.2)
	glow.Rate = 3
	glow.Speed = NumberRange.new(0, 0)
	glow.LockedToPart = true
	glow.ZOffset = -1.5
	glow.Parent = attachment

	model:SetAttribute("Rarity", rarityName)
	if rainbow then
		for _, piece in ipairs({ light, aura, glow }) do
			CollectionService:AddTag(piece, TreasureModels.RAINBOW_TAG)
		end
	end
end

-- Decorative parts: no collisions, queries or touches.
function TreasureModels.SetDecorative(model, anchored)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
end

return TreasureModels
