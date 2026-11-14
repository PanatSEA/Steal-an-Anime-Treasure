-- TreasureModels: the chest and dirt mound, loaded by name (used by server and client).
--   ReplicatedStorage/Models/Treasures/Chests/Chest_<Rarity>
--       One chest model per rarity (Chest_Common, Chest_Epic, Chest_Legendary, Chest_Secret),
--       prepared with tools/PrepareChests.luau: "Base" PrimaryPart with the model's pivot at the
--       bottom centre, front (gem side) facing -Z, optional "Trim" / "Gem" parts welded to
--       Base, 3.3 studs wide. Chests have no lid: they open with a squash and a burst (ChestFx).
--       A missing rarity falls back to Chest_Common, then to Models/Treasures/Chest (the
--       older single chest, if present), then to the part-built placeholder below.
--   ReplicatedStorage/Models/Treasures/DirtMound
--       Built by tools/BuildDirtMound.luau. PrimaryPart "Root" at ground level; parts tagged
--       with a DigLayer attribute (1 = top) fly off layer by layer on hits; ChestPose0/1/2
--       attributes place the chest at each stage (see the tool's header).
-- If a model is missing, a part-built placeholder is used instead.
-- Rarity is shown by the chest model itself, its Neon Gem in the rarity colour, and the rarity
-- aura clients add via AURA_TAG (glow, gem light, sparkles, sky beam, shimmer: ChestAura,
-- tuned in ChestFxPresets.RarityFx). The chest is never repainted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(script.Parent:WaitForChild("AnimeConfig"))
local ChestFxPresets = require(script.Parent:WaitForChild("ChestFxPresets"))
local World = AnimeConfig.World

local TreasureModels = {}

-- Chests with this tag get the rarity aura on every client (ChestAura). Carry.MakeTreasure tags
-- carried and plot chests; DigClient tags the emerged chest.
TreasureModels.AURA_TAG = "ChestAura"

local CHESTS_FOLDER = "Chests" -- Models/Treasures/Chests/Chest_<Rarity>
local DEFAULT_CHEST_RARITY = "Common"

-- A model under Models/Treasures by path, e.g. source("DirtMound") or source("Chests", "Chest_Epic").
local function source(...)
	local models = ReplicatedStorage:FindFirstChild(World.ModelsFolderName)
	local node = models and models:FindFirstChild(World.TreasureModelsFolderName)
	for _, name in ipairs({ ... }) do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("Model") and node.PrimaryPart then
		return node
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

-- The old part-built chest (wood, metal trim, gold lock, moss); its lid no longer opens.
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

-- The chest for a rarity (nil = not rolled yet, e.g. still buried): Chest_<Rarity>, else
-- Chest_Common, else the older Models/Treasures/Chest, else the part-built placeholder.
function TreasureModels.Chest(rarityName)
	local found = (rarityName and source(CHESTS_FOLDER, "Chest_" .. rarityName))
		or source(CHESTS_FOLDER, "Chest_" .. DEFAULT_CHEST_RARITY)
		or source("Chest")
	return found and found:Clone() or fallbackChest()
end

function TreasureModels.DirtMound()
	local found = source("DirtMound")
	return found and found:Clone() or fallbackMound()
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

-- The rarity colour (ChestFxPresets.RarityTint, matching the chests' trims).
function TreasureModels.GlowColor(rarityName)
	local tints = ChestFxPresets.RarityTint
	return tints[rarityName] or tints.Common
end

-- Stamps the chest with its rarity (clients read it for the rarity aura) and lights its Gem:
-- Neon in the rarity colour. The gem's PointLight is added by ChestAura on clients (one light
-- per chest, culled with distance). Never repaints the chest. `anchored` is unused (kept for callers).
function TreasureModels.ApplyRarityGlow(model, rarityName, _anchored)
	model:SetAttribute("Rarity", rarityName)
	local gem = model:FindFirstChild("Gem", true)
	if rarityName and gem and gem:IsA("BasePart") then
		gem.Material = Enum.Material.Neon
		gem.Color = TreasureModels.GlowColor(rarityName)
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
