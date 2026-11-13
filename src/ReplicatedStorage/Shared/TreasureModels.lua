-- TreasureModels: loads the chest and dirt mound by name (used by server and client).
--   ReplicatedStorage/Models/Treasures/Chest
--       PrimaryPart "Base" (lowest part); parts named "Trim" take the rarity colour;
--       a Model "Lid" whose PrimaryPart sits on the back hinge line (front = -Z).
--   ReplicatedStorage/Models/Treasures/DirtMound
--       PrimaryPart "Root" at ground level; parts named "Chunk" break off on hits.
-- Missing models fall back to simple placeholder shapes, so you can swap in your own any time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(script.Parent:WaitForChild("AnimeConfig"))
local World = AnimeConfig.World

local TreasureModels = {}

local DEFAULT_TRIM = Color3.fromRGB(85, 85, 95)

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

local function fallbackChest()
	local model = Instance.new("Model")
	model.Name = "Chest"
	local base = part({ Name = "Base", Size = Vector3.new(3, 1.6, 2), CFrame = CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(150, 95, 55), Parent = model })
	part({ Name = "Trim", Size = Vector3.new(3.06, 0.25, 2.06), CFrame = CFrame.new(0, 1.45, 0), Color = DEFAULT_TRIM, Parent = model })
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = model
	part({ Name = "LidTop", Size = Vector3.new(3.1, 0.7, 2.1), CFrame = CFrame.new(0, 1.95, 0), Color = Color3.fromRGB(170, 110, 62), Parent = lid })
	lid.PrimaryPart = part({ Name = "LidHinge", Size = Vector3.new(3.1, 0.1, 0.1), CFrame = CFrame.new(0, 1.6, 1.05), Transparency = 1, Parent = lid })
	model.PrimaryPart = base
	return model
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

-- Tints every part named "Trim" to the rarity colour.
function TreasureModels.ApplyRarity(model, rarityName)
	local rarity = AnimeConfig.Rarities[rarityName]
	local color = rarity and rarity.Color or DEFAULT_TRIM
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Trim" then
			descendant.Color = color
			descendant.Material = Enum.Material.Metal
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
