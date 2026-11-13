-- Run once in Studio (Edit mode, command bar) to build the Phase 4 placeholder models:
--   ReplicatedStorage.Models.Treasures.Chest      stylized low-poly chest (wood, metal trim, moss)
--   ReplicatedStorage.Models.Treasures.DirtMound  rounded cartoon dirt mound with rocks and pebbles
-- Safe to re-run: it replaces both models. Replace either with your own model of the same
-- name later. Contract the scripts rely on:
--   Chest:     PrimaryPart "Base" (the lowest part); parts named "Trim" take the rarity colour;
--              a Model "Lid" whose PrimaryPart sits on the back hinge line (front of the chest = -Z).
--   DirtMound: PrimaryPart "Root" at ground level; parts named "Chunk" break off on each hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local treasures = folder(folder(ReplicatedStorage, "Models"), "Treasures")
for _, name in ipairs({ "Chest", "DirtMound" }) do
	local old = treasures:FindFirstChild(name)
	if old then
		old:Destroy()
	end
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

-- A part rendered as an ellipsoid of its own size (rounded cartoon look).
local function blob(props)
	local p = part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Chest ------------------------------------------------------------------------
local WOOD = Color3.fromRGB(150, 95, 55)
local WOOD_LIGHT = Color3.fromRGB(170, 110, 62)
local WOOD_DARK = Color3.fromRGB(110, 68, 38)
local METAL = Color3.fromRGB(85, 85, 95)
local GOLD = Color3.fromRGB(255, 200, 60)
local MOSS = Color3.fromRGB(95, 160, 65)

local chest = Instance.new("Model")
chest.Name = "Chest"

local base = part({ Name = "Base", Size = Vector3.new(3.2, 1.6, 2.2), CFrame = CFrame.new(0, 0.8, 0), Color = WOOD, Parent = chest })
for _, y in ipairs({ 0.55, 1.1 }) do
	part({ Name = "Plank", Size = Vector3.new(3.22, 0.07, 2.22), CFrame = CFrame.new(0, y, 0), Color = WOOD_DARK, Parent = chest })
end
for _, x in ipairs({ -1.05, 1.05 }) do
	part({ Name = "Trim", Size = Vector3.new(0.28, 1.64, 2.26), CFrame = CFrame.new(x, 0.8, 0), Color = METAL, Material = Enum.Material.Metal, Parent = chest })
end
part({ Name = "Trim", Size = Vector3.new(3.26, 0.22, 2.26), CFrame = CFrame.new(0, 0.11, 0), Color = METAL, Material = Enum.Material.Metal, Parent = chest })
part({ Name = "Lock", Size = Vector3.new(0.55, 0.65, 0.15), CFrame = CFrame.new(0, 1.5, -1.17), Color = GOLD, Material = Enum.Material.Metal, Parent = chest })
part({ Name = "Keyhole", Size = Vector3.new(0.12, 0.22, 0.05), CFrame = CFrame.new(0, 1.45, -1.25), Color = Color3.fromRGB(30, 25, 20), Parent = chest })
part({ Name = "Moss", Size = Vector3.new(0.14, 0.6, 0.9), CFrame = CFrame.new(1.67, 0.42, 0.4), Color = MOSS, Parent = chest })

local lid = Instance.new("Model")
lid.Name = "Lid"
lid.Parent = chest
local hinge = part({ Name = "LidHinge", Size = Vector3.new(3.3, 0.1, 0.1), CFrame = CFrame.new(0, 1.6, 1.15), Transparency = 1, Parent = lid })
part({ Name = "LidTop", Size = Vector3.new(3.3, 0.75, 2.3), CFrame = CFrame.new(0, 1.975, 0), Color = WOOD_LIGHT, Parent = lid })
part({ Name = "LidPlank", Size = Vector3.new(3.32, 0.07, 2.32), CFrame = CFrame.new(0, 2.15, 0), Color = WOOD_DARK, Parent = lid })
for _, x in ipairs({ -1.05, 1.05 }) do
	part({ Name = "Trim", Size = Vector3.new(0.3, 0.79, 2.34), CFrame = CFrame.new(x, 1.975, 0), Color = METAL, Material = Enum.Material.Metal, Parent = lid })
end
part({ Name = "Moss", Size = Vector3.new(1.0, 0.12, 0.8), CFrame = CFrame.new(-0.55, 2.41, 0.35), Color = MOSS, Parent = lid })
part({ Name = "Moss", Size = Vector3.new(0.6, 0.1, 0.5), CFrame = CFrame.new(0.5, 2.4, -0.55), Color = MOSS, Parent = lid })
lid.PrimaryPart = hinge

chest.PrimaryPart = base
chest.Parent = treasures

-- Dirt mound -------------------------------------------------------------------
local DIRT = { Color3.fromRGB(120, 78, 45), Color3.fromRGB(132, 86, 50), Color3.fromRGB(105, 68, 40) }
local ROCK = { Color3.fromRGB(125, 122, 120), Color3.fromRGB(100, 98, 96), Color3.fromRGB(145, 140, 132) }
local rng = Random.new(42) -- fixed seed so the saved model is always the same

local mound = Instance.new("Model")
mound.Name = "DirtMound"
local root = part({ Name = "Root", Size = Vector3.new(8, 0.2, 8), CFrame = CFrame.new(0, 0.1, 0), Transparency = 1, Parent = mound })
blob({ Name = "Body", Size = Vector3.new(8, 3.2, 8), CFrame = CFrame.new(0, 0, 0), Color = DIRT[1], Parent = mound })

for i = 1, 5 do
	local angle = (i / 5) * math.pi * 2 + 0.4
	local size = Vector3.new(rng:NextNumber(2.2, 3.0), rng:NextNumber(1.3, 1.8), rng:NextNumber(2.0, 2.8))
	blob({
		Name = "Chunk",
		Size = size,
		CFrame = CFrame.new(math.cos(angle) * 2.1, 0.95, math.sin(angle) * 2.1) * CFrame.Angles(0, angle, 0),
		Color = DIRT[(i % 3) + 1],
		Parent = mound,
	})
end
for i = 1, 3 do
	local angle = i * 2.1
	part({
		Name = "Crack",
		Size = Vector3.new(0.14, 0.06, rng:NextNumber(1.1, 1.7)),
		CFrame = CFrame.new(math.cos(angle) * 0.5, 1.6, math.sin(angle) * 0.5) * CFrame.Angles(0, angle, 0),
		Color = Color3.fromRGB(60, 38, 22),
		Parent = mound,
	})
end
for i = 1, 5 do
	local angle = (i / 5) * math.pi * 2 + rng:NextNumber(0, 0.6)
	local s = rng:NextNumber(0.7, 1.1)
	part({
		Name = "Rock",
		Size = Vector3.new(s, s * 0.7, s * 0.9),
		CFrame = CFrame.new(math.cos(angle) * 4.0, 0.25, math.sin(angle) * 4.0)
			* CFrame.Angles(rng:NextNumber(0, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(0, 0.6)),
		Color = ROCK[(i % 3) + 1],
		Parent = mound,
	})
end
for i = 1, 8 do
	local angle = (i / 8) * math.pi * 2 + rng:NextNumber(0, 0.5)
	local s = rng:NextNumber(0.28, 0.45)
	blob({
		Name = "Pebble",
		Size = Vector3.new(s, s * 0.7, s),
		CFrame = CFrame.new(math.cos(angle) * rng:NextNumber(4.4, 5.1), 0.12, math.sin(angle) * rng:NextNumber(4.4, 5.1)),
		Color = (i % 2 == 0) and ROCK[(i % 3) + 1] or DIRT[(i % 3) + 1],
		Parent = mound,
	})
end

mound.PrimaryPart = root
mound.Parent = treasures

return "Built ReplicatedStorage.Models.Treasures.Chest and DirtMound"
