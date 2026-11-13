-- Zones: SAFE ZONE and base-plot checks (pure position math, no Touched events).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local World = AnimeConfig.World

local Zones = {}

local function pointInPart(part, pos, extraHeight)
	local localPos = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Z) <= half.Z
		and localPos.Y >= -half.Y
		and localPos.Y <= half.Y + (extraHeight or 0)
end

function Zones.IsInSafeZone(pos)
	local gameFolder = Workspace:FindFirstChild(World.GameFolderName)
	local folder = gameFolder and gameFolder:FindFirstChild(World.SafeZoneFolderName)
	if not folder then
		return false
	end
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") and pointInPart(part, pos) then
			return true
		end
	end
	return false
end

-- Returns the base plot the position is standing on, or nil.
function Zones.FindPlotAt(pos)
	local node = Workspace
	for _, name in ipairs(World.PlotsPath) do
		node = node and node:FindFirstChild(name)
	end
	if not node then
		return nil
	end
	for _, part in ipairs(node:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == World.PlotPartName and pointInPart(part, pos, 8) then
			return part
		end
	end
	return nil
end

return Zones
