-- Run once in Studio (Edit mode, command bar) to build the Phase 1 placeholder world.
-- Safe to re-run: it replaces Workspace.TreasureGame.
-- Layout: SAFE ZONE covers the lobby baseplate (all 8 base plots);
-- the treasure field extends west of the lobby with Boss_01's dig site.

local old = workspace:FindFirstChild("TreasureGame")
if old then old:Destroy() end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local root = Instance.new("Folder")
root.Name = "TreasureGame"

local safeZones = Instance.new("Folder")
safeZones.Name = "SafeZones"
safeZones.Parent = root

-- Invisible volume over the lobby baseplate (center 72,57,-33 / 400x400).
part({
	Name = "SafeZone_Lobby", Size = Vector3.new(400, 44, 400), Position = Vector3.new(72, 79, -33),
	Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	Parent = safeZones,
})

-- Green line on the lobby's west edge so players can see where safety starts.
part({
	Name = "SafeZoneBorder", Size = Vector3.new(1, 0.3, 400), Position = Vector3.new(-127.5, 59.2, -33),
	Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 255, 120),
	CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	Parent = root,
})

-- Treasure field west of the lobby (top surface y = 59, flush with the lobby).
part({
	Name = "TreasureField", Size = Vector3.new(400, 4, 400), Position = Vector3.new(-328, 57, -33),
	Material = Enum.Material.Sand, Color = Color3.fromRGB(205, 180, 125),
	Parent = root,
})

local digSites = Instance.new("Folder")
digSites.Name = "DigSites"
digSites.Parent = root

local site = Instance.new("Model")
site.Name = "DigSite_Boss_01"
site:SetAttribute("BossId", "Boss_01")
site.Parent = digSites

part({
	Name = "DigMound", Size = Vector3.new(8, 2, 8), Position = Vector3.new(-400, 60, -33),
	Material = Enum.Material.Ground, Color = Color3.fromRGB(110, 75, 45),
	Parent = site,
})
part({
	Name = "BossSpawn", Size = Vector3.new(6, 1, 6), Position = Vector3.new(-416, 59.5, -33),
	Orientation = Vector3.new(0, -90, 0), -- face east toward the lobby
	Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	Parent = site,
})
site.PrimaryPart = site.DigMound

local effects = Instance.new("Folder")
effects.Name = "Effects"
effects.Parent = root

root.Parent = workspace

-- Script containers
local shared = game.ReplicatedStorage:FindFirstChild("Shared") or Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = game.ReplicatedStorage
local tg = game.ServerScriptService:FindFirstChild("TreasureGame") or Instance.new("Folder")
tg.Name = "TreasureGame"
tg.Parent = game.ServerScriptService

return "Phase 1 world built"
