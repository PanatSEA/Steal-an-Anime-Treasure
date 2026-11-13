-- Run once in Studio (Edit mode, command bar) to build the Phase 4 placeholder dirt mound:
--   ReplicatedStorage.Models.Treasures.DirtMound  rounded cartoon dirt mound with rocks and pebbles
-- Safe to re-run: it replaces only DirtMound. It never touches Models/Treasures/Chest
-- (your own chest model; prepare it with tools/PrepareChestModel.luau). The old
-- part-built chest now lives in ReplicatedStorage.Shared.TreasureModels as the fallback.
-- Contract the scripts rely on:
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
local oldMound = treasures:FindFirstChild("DirtMound")
if oldMound then
	oldMound:Destroy()
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

return "Built ReplicatedStorage.Models.Treasures.DirtMound"
