-- Run in Studio (Edit mode, command bar) to (re)build the dig mound:
--   ReplicatedStorage.Models.Treasures.DirtMound
-- A lumpy 3-layer pile of sand-coloured stud blocks (same "2022 Stud" look as the tracks),
-- loose blocks around the base, 3 glowing ice-blue crystal clusters, and a gap in the top
-- layer where the chest corner pokes out. Styled after docs/References/DirtMound_Ref.png.
-- Safe to re-run: it replaces only DirtMound and never touches the chests (Models/Treasures/Chests).
--
-- Contract DigClient relies on:
--   * PrimaryPart "Root" at ground level, centre of the mound. Local -Z is the front.
--   * Every block has attribute DigLayer: 1 = top (flies off on hit 1), 2 = middle (hit 2),
--     3 = bottom + loose blocks (burst on the last hit). Crystals carry their layer too.
--   * Parts named "Crystal" twinkle on untouched mounds.
--   * Model attributes ChestPose0/1/2 (CFrame, relative to the Root pivot): where the chest
--     sits before hit 1 / after hit 1 / after hit 2.
--   * Body blocks CanCollide; loose blocks and crystals don't.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialService = game:GetService("MaterialService")

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

local STUD_VARIANT = "2022 Stud" -- MaterialService variant the tracks use
local hasVariant = MaterialService:FindFirstChild(STUD_VARIANT, true) ~= nil
-- The Glacier base of the stud variant renders paler, so these are darker than the floor sand.
local SAND = { Color3.fromRGB(196, 158, 108), Color3.fromRGB(186, 148, 98), Color3.fromRGB(176, 140, 92) }
local LAYER_H = 0.95 -- block heights below are multiplied by this (one layer is about 1.25 studs)
local ICE = Color3.fromRGB(70, 190, 255)
local rng = Random.new(7) -- fixed seed so the saved model is always the same

local mound = Instance.new("Model")
mound.Name = "DirtMound"

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = mound
	return p
end

local blockCount = 0

-- A sand block: centre (x, z) on the ground plan, bottom at y0, height h, turned yaw degrees,
-- with a small random tilt so the layers don't look machine-stacked.
local function block(layer, x, z, sx, sz, y0, h, yaw, collide)
	blockCount += 1
	h *= LAYER_H
	local tiltX, tiltZ = rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)
	local p = newPart({
		Name = "Block",
		Size = Vector3.new(sx, h, sz),
		CFrame = CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(math.rad(tiltX), math.rad(yaw), math.rad(tiltZ)),
		Color = SAND[(blockCount % #SAND) + 1],
		Material = hasVariant and Enum.Material.Glacier or Enum.Material.Plastic,
		CanCollide = collide ~= false,
	})
	if hasVariant then
		p.MaterialVariant = STUD_VARIANT
	else
		p.TopSurface = Enum.SurfaceType.Studs
	end
	p:SetAttribute("DigLayer", layer)
	return p
end

newPart({
	Name = "Root",
	Size = Vector3.new(8, 0.2, 8),
	CFrame = CFrame.new(0, 0.1, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
})

-- Bottom layer (3): about 8 x 8.
local B = 0
block(3, -2.0, -2.0, 3.8, 3.6, B, 1.40, 4)
block(3, 2.1, -1.9, 3.6, 3.8, B, 1.35, -5)
block(3, -2.1, 2.0, 3.9, 3.5, B, 1.45, -3)
block(3, 2.0, 2.1, 3.5, 3.7, B, 1.40, 6)
block(3, 0.0, 0.0, 2.6, 2.6, B, 1.50, 12)
block(3, 0.2, -3.7, 2.6, 1.5, B, 1.20, 8)
block(3, -3.9, 0.3, 1.5, 2.8, B, 1.25, -7)
block(3, 3.9, -0.2, 1.6, 2.6, B, 1.30, 5)
block(3, 0.4, 3.8, 2.8, 1.5, B, 1.15, -4)

-- Middle layer (2): about 6 x 6.
local M = 1.3 * LAYER_H
block(2, -1.6, -1.5, 3.0, 2.8, M, 1.30, -6)
block(2, 1.5, -1.6, 2.9, 3.0, M, 1.35, 5)
block(2, -1.5, 1.6, 3.0, 3.0, M, 1.25, 7)
block(2, 1.6, 1.5, 2.8, 2.9, M, 1.30, -4)
-- Pedestal under the chest: tagged with the bottom layer so it holds the chest up until the
-- last hit. Its top is where the chest rests after hit 2 (ChestPose2).
local PEDESTAL_TOP = 2.6
block(3, 0.0, 0.4, 2.2, 2.0, M, (PEDESTAL_TOP - M) / LAYER_H, 0).Name = "Pedestal"
block(2, -0.3, -2.9, 2.0, 1.2, M, 1.10, 3)
block(2, -2.9, 0.0, 1.2, 2.0, M, 1.15, -8)
block(2, 3.0, 0.3, 1.1, 1.8, M, 1.20, 6)

-- Top layer (1): a ring of blocks around the gap where the chest pokes out (chest sits at z +0.4).
local T = 2.55 * LAYER_H
block(1, -1.2, -1.6, 2.4, 1.6, T, 1.20, -5)
block(1, 1.3, -1.4, 2.0, 1.8, T, 1.25, 7)
block(1, -1.9, 1.3, 1.4, 2.2, T, 1.10, 4)
block(1, 1.9, 1.5, 1.3, 2.0, T, 1.20, -6)
block(1, 0.1, 2.3, 2.0, 1.0, T, 1.00, 3)
block(1, -1.9, 1.2, 1.2, 1.0, T + 1.1 * LAYER_H, 0.5, 18) -- small cap on the back-left block

-- Loose blocks scattered around the base (3: burst with the bottom layer; no collision).
for i = 1, 7 do
	local angle = (i / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	local r = rng:NextNumber(5.0, 6.2)
	local s = rng:NextNumber(0.9, 1.4)
	local loose = block(3, math.cos(angle) * r, math.sin(angle) * r, s * rng:NextNumber(1, 1.3), s, 0, s * 0.85,
		rng:NextNumber(0, 90), false)
	loose.Name = "LooseBlock"
end

-- Ice-blue crystal clusters stuck into the sides: 3 Neon shards + a small light each.
local function crystalCluster(layer, base, outward)
	local dir = outward.Unit
	local frame = CFrame.lookAt(base, base + dir) * CFrame.Angles(-math.pi / 2, 0, 0) -- +Y along dir
	local shards = {
		{ size = Vector3.new(0.85, 2.2, 0.85), turn = CFrame.Angles(0, math.rad(45), 0) },
		{ size = Vector3.new(0.65, 1.55, 0.65), turn = CFrame.Angles(math.rad(30), math.rad(20), math.rad(-18)) },
		{ size = Vector3.new(0.6, 1.35, 0.6), turn = CFrame.Angles(math.rad(-24), math.rad(65), math.rad(26)) },
	}
	for i, shard in ipairs(shards) do
		local p = newPart({
			Name = "Crystal",
			Size = shard.size,
			-- sunk 30% into the block so it reads as growing out of it
			CFrame = frame * shard.turn * CFrame.new(0, shard.size.Y * 0.2, 0),
			Color = ICE,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		p:SetAttribute("DigLayer", layer)
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = ICE
			light.Range = 4
			light.Brightness = 0.7
			light.Parent = p
		end
	end
end

crystalCluster(2, Vector3.new(-3.0, 1.85, -0.6), Vector3.new(-1, 0.55, -0.35)) -- left side, middle
crystalCluster(2, Vector3.new(3.0, 2.0, 0.9), Vector3.new(1, 0.6, -0.2)) -- right side, middle
crystalCluster(3, Vector3.new(0.9, 0.8, -3.95), Vector3.new(0.15, 0.55, -1)) -- front, bottom

-- Where the chest sits (pivot at its bottom centre, front facing -Z like the mound):
-- tilted with its lid out of the top gap, then higher and straighter as each layer comes
-- off, ending flat on the pedestal.
local function pose(y, tiltX, tiltZ)
	return CFrame.new(0, y, 0.4) * CFrame.Angles(math.rad(tiltX), 0, math.rad(tiltZ))
end
mound:SetAttribute("ChestPose0", pose(2.1, -14, 12))
mound:SetAttribute("ChestPose1", pose(2.35, -6, 6))
mound:SetAttribute("ChestPose2", pose(PEDESTAL_TOP, 0, 0))

mound.PrimaryPart = mound.Root
mound.Parent = treasures

local count = 0
for _, d in ipairs(mound:GetDescendants()) do
	if d:IsA("BasePart") then
		count += 1
	end
end
return ("Built ReplicatedStorage.Models.Treasures.DirtMound (%d parts)"):format(count)
