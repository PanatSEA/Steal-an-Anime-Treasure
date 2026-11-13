-- Run in Studio (Edit mode, command bar) after dropping in a new chest model at
-- ReplicatedStorage.Models.Treasures.Chest. Safe to re-run.
--   * Rebuilds it into a fresh Model (clears any odd import scale, e.g. 0.0193)
--   * Resizes it to TARGET_WIDTH studs wide (same as the old part-built chest)
--   * Adds an invisible "Root" part at the bottom centre as PrimaryPart, with the
--     pivot exactly at the bottom centre. The chest must be upright with its front
--     (lock side) facing -Z, as imported.
--   * Every visible part: Anchored = false, CanCollide = false, CanTouch = false,
--     CanQuery = false, Massless = true, PivotOffset reset, welded to Root
-- A Model named "Lid" with its PrimaryPart on the back hinge is optional: with one,
-- chests open with a lid animation; without one (a single mesh), they open with a burst.

local TARGET_WIDTH = 3.3
local ROOT_SIZE = 0.2

local treasures = game:GetService("ReplicatedStorage").Models.Treasures
local source = treasures:FindFirstChild("Chest")
assert(source and source:IsA("Model"), "ReplicatedStorage.Models.Treasures.Chest not found")

local oldRoot = source.PrimaryPart
if oldRoot and oldRoot.Name == "Root" and math.abs(source:GetScale() - 1) < 1e-3 then
	return "Chest already prepared"
end

-- World-axis bounding box (ignores any rotated PivotOffset from the import).
local function worldBox(parts)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, part in ipairs(parts) do
		local half = part.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					minV = minV:Min(corner)
					maxV = maxV:Max(corner)
				end
			end
		end
	end
	return minV, maxV
end

-- Move everything into a fresh Model so its scale starts at 1.
local model = Instance.new("Model")
model.Name = "Chest"
for _, child in ipairs(source:GetChildren()) do
	child.Parent = model
end
if oldRoot and oldRoot.Name == "Root" then
	oldRoot:Destroy()
end

local parts = {}
for _, part in ipairs(model:GetDescendants()) do
	if part:IsA("BasePart") then
		part.PivotOffset = CFrame.new()
		table.insert(parts, part)
	end
end
assert(#parts > 0, "Chest has no parts")

local minV, maxV = worldBox(parts)
model.WorldPivot = CFrame.new((minV + maxV) / 2)
model:ScaleTo(TARGET_WIDTH / (maxV.X - minV.X))
minV, maxV = worldBox(parts)

local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(ROOT_SIZE, ROOT_SIZE, ROOT_SIZE)
root.Transparency = 1
root.Anchored = false
root.CanCollide = false
root.CanTouch = false
root.CanQuery = false
root.Massless = true
root.CFrame = CFrame.new((minV.X + maxV.X) / 2, minV.Y + ROOT_SIZE / 2, (minV.Z + maxV.Z) / 2)
root.PivotOffset = CFrame.new(0, -ROOT_SIZE / 2, 0) -- pivot exactly at the bottom centre
root.Parent = model

for _, part in ipairs(parts) do
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	for _, joint in ipairs(part:GetChildren()) do
		if joint:IsA("WeldConstraint") and joint.Name == "WeldToRoot" then
			joint:Destroy()
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "WeldToRoot"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

-- Second fresh Model so GetScale() reports 1 at the new size.
local final = Instance.new("Model")
final.Name = "Chest"
for _, child in ipairs(model:GetChildren()) do
	child.Parent = final
end
final.PrimaryPart = root
final:PivotTo(CFrame.new())
source:Destroy()
model:Destroy()
final.Parent = treasures

local _, size = final:GetBoundingBox()
return ("Chest prepared: %d part(s) + Root, %.2f x %.2f x %.2f, scale %.3f"):format(
	#parts, size.X, size.Y, size.Z, final:GetScale())
