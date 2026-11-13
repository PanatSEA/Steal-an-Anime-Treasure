-- Run once in Studio (Edit mode, command bar) to build the placeholder dig mound:
--   ReplicatedStorage.Models.Treasures.DirtMound  pale cartoon rock mound with blue crystals
--   (styled after the reference picture: cream rock, blue crystal shards, tan chunks)
-- Safe to re-run: it replaces only DirtMound. It never touches Models/Treasures/Chest
-- (your own chest model; prepare it with tools/PrepareChestModel.luau). The old
-- part-built chest lives in ReplicatedStorage.Shared.TreasureModels as the fallback.
-- Contract the scripts rely on:
--   DirtMound: PrimaryPart "Root" at ground level; parts named "Chunk" or "Crystal" break off on hits.

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

local ROCK = { Color3.fromRGB(198, 172, 130), Color3.fromRGB(212, 188, 148), Color3.fromRGB(176, 150, 112) }
local CRACK = Color3.fromRGB(118, 90, 60)
local CRYSTAL = { Color3.fromRGB(64, 132, 245), Color3.fromRGB(96, 172, 255), Color3.fromRGB(46, 104, 226) }
local RADIUS, HEIGHT = 4, 1.6 -- ellipsoid body semi-axes (x/z, y)
local rng = Random.new(42) -- fixed seed so the saved model is always the same

local mound = Instance.new("Model")
mound.Name = "DirtMound"
local root = part({ Name = "Root", Size = Vector3.new(8, 0.2, 8), CFrame = CFrame.new(0, 0.1, 0), Transparency = 1, Parent = mound })
blob({ Name = "Body", Size = Vector3.new(RADIUS * 2, HEIGHT * 2, RADIUS * 2), CFrame = CFrame.new(0, 0, 0), Color = ROCK[1], Parent = mound })

-- Rock lumps on top (break off on hits).
for i = 1, 5 do
	local angle = (i / 5) * math.pi * 2 + 0.4
	local size = Vector3.new(rng:NextNumber(2.2, 3.0), rng:NextNumber(1.3, 1.8), rng:NextNumber(2.0, 2.8))
	blob({
		Name = "Chunk",
		Size = size,
		CFrame = CFrame.new(math.cos(angle) * 2.1, 0.95, math.sin(angle) * 2.1) * CFrame.Angles(0, angle, 0),
		Color = ROCK[(i % 3) + 1],
		Parent = mound,
	})
end

-- Cracks across the top.
for i = 1, 3 do
	local angle = i * 2.1
	part({
		Name = "Crack",
		Size = Vector3.new(0.14, 0.06, rng:NextNumber(1.1, 1.7)),
		CFrame = CFrame.new(math.cos(angle) * 0.5, 1.6, math.sin(angle) * 0.5) * CFrame.Angles(0, angle, 0),
		Color = CRACK,
		Parent = mound,
	})
end

-- Blue crystal shards poking out of the rock, leaning outward (they fly off on hits too).
local function crystal(base, dir, length, width, color)
	local look = CFrame.lookAt(base, base + dir) * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y along dir
	return part({
		Name = "Crystal",
		Size = Vector3.new(width, length, width),
		CFrame = look * CFrame.new(0, length / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = color,
		Reflectance = 0.15,
		Parent = mound,
	})
end

for i = 1, 9 do
	local angle = (i / 9) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
	local r = rng:NextNumber(2.3, 3.5)
	local x, z = math.cos(angle) * r, math.sin(angle) * r
	local y = HEIGHT * math.sqrt(math.max(0, 1 - (r / RADIUS) ^ 2))
	local normal = Vector3.new(x / RADIUS ^ 2, y / HEIGHT ^ 2, z / RADIUS ^ 2).Unit
	local dir = (normal + Vector3.new(0, 0.5, 0)).Unit
	crystal(Vector3.new(x, y - 0.3, z), dir, rng:NextNumber(1.0, 1.9), rng:NextNumber(0.45, 0.75), CRYSTAL[(i % 3) + 1])
end

-- Small crystal bits and pale pebbles scattered around the base.
for i = 1, 8 do
	local angle = (i / 8) * math.pi * 2 + rng:NextNumber(0, 0.5)
	local r = rng:NextNumber(4.3, 5.1)
	local pos = Vector3.new(math.cos(angle) * r, 0.1, math.sin(angle) * r)
	if i % 2 == 0 then
		local dir = Vector3.new(math.cos(angle) * 0.6, 1, math.sin(angle) * 0.6).Unit
		crystal(pos, dir, rng:NextNumber(0.5, 0.8), rng:NextNumber(0.25, 0.35), CRYSTAL[(i % 3) + 1])
	else
		local s = rng:NextNumber(0.3, 0.5)
		blob({ Name = "Pebble", Size = Vector3.new(s, s * 0.7, s), CFrame = CFrame.new(pos), Color = ROCK[(i % 3) + 1], Parent = mound })
	end
end

mound.PrimaryPart = root
mound.Parent = treasures

return "Built ReplicatedStorage.Models.Treasures.DirtMound"
