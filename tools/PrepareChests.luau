-- Run in Studio (Edit mode, command bar) after dropping chest models into
-- ReplicatedStorage.Models.Treasures.Chests (Chest_Common, Chest_Epic, Chest_Legendary,
-- Chest_Secret). Prepares every Chest_* model there; safe to re-run (prepared ones are skipped).
-- Each chest must be upright with its front (gem side) facing -Z, as imported.
--   * "Base" is the main body: the part already named Base, else the model's PrimaryPart, else
--     its largest part (renamed Base). Optional "Trim" / "Gem" parts are kept as they are.
--   * Rebuilds it into a fresh Model (clears any odd import scale, e.g. 0.0275) and resizes it
--     to TARGET_WIDTH studs wide (the size of the old chest)
--   * Base becomes the PrimaryPart, with the model's pivot exactly at the bottom centre
--   * Every part: Anchored = false (the game anchors plot chests itself; carried chests stay
--     unanchored), CanCollide / CanTouch / CanQuery = false (all decorative: a carried chest
--     must never push its carrier), Massless = true except Base; Trim / Gem welded to Base
--   * A chest without a "Gem" part gets one: a small part over the gem painted on the front
--     plate (half the chest's height, flush with the front), welded to Base. The game turns it
--     Neon in the rarity colour (TreasureModels.ApplyRarityGlow) and hangs the chest's light on it.
-- Chests have no lid: they open with a squash and a burst (ChestFx).

local TARGET_WIDTH = 3.3
local GEM_SIZE = Vector3.new(0.17, 0.25, 0.05)
local GEM_HEIGHT = 0.5 -- fraction of the chest's height (all four chests put the gem plate here)
local GEM_INSET = 0.01 -- studs behind the front of the bounding box (the plate sits about there)

local chests = game:GetService("ReplicatedStorage").Models.Treasures:FindFirstChild("Chests")
assert(chests, "ReplicatedStorage.Models.Treasures.Chests not found")

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

local function isPrepared(source)
	local base = source.PrimaryPart
	if not (base and base.Name == "Base" and math.abs(source:GetScale() - 1) < 1e-3) then
		return false
	end
	local _, size = source:GetBoundingBox()
	return math.abs(size.X - TARGET_WIDTH) < 0.01
end

local function prepare(source)
	local parts = {}
	for _, part in ipairs(source:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	assert(#parts > 0, source.Name .. " has no parts")

	local base = source:FindFirstChild("Base", true) or source.PrimaryPart
	if not (base and base:IsA("BasePart")) then
		base = parts[1]
		for _, part in ipairs(parts) do
			if part.Size.X * part.Size.Y * part.Size.Z > base.Size.X * base.Size.Y * base.Size.Z then
				base = part
			end
		end
	end
	base.Name = "Base"

	-- Move everything into a fresh Model so its scale starts at 1.
	local model = Instance.new("Model")
	for _, child in ipairs(source:GetChildren()) do
		child.Parent = model
	end
	for _, part in ipairs(parts) do
		part.PivotOffset = CFrame.new()
	end

	local minV, maxV = worldBox(parts)
	model.WorldPivot = CFrame.new((minV + maxV) / 2)
	model:ScaleTo(TARGET_WIDTH / (maxV.X - minV.X))
	minV, maxV = worldBox(parts)

	-- Pivot at the bottom centre, world-aligned (front stays -Z).
	local bottomCentre = Vector3.new((minV.X + maxV.X) / 2, minV.Y, (minV.Z + maxV.Z) / 2)
	base.PivotOffset = base.CFrame:ToObjectSpace(CFrame.new(bottomCentre))

	for _, part in ipairs(parts) do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = part ~= base
		for _, joint in ipairs(part:GetChildren()) do
			if joint:IsA("WeldConstraint") and (joint.Name == "WeldToBase" or joint.Name == "WeldToRoot") then
				joint:Destroy()
			end
		end
		if part ~= base then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "WeldToBase"
			weld.Part0 = base
			weld.Part1 = part
			weld.Parent = part
		end
	end

	-- Second fresh Model so GetScale() reports 1 at the new size.
	local final = Instance.new("Model")
	final.Name = source.Name
	for _, child in ipairs(model:GetChildren()) do
		child.Parent = final
	end
	final.PrimaryPart = base
	final:PivotTo(CFrame.new())
	source:Destroy()
	model:Destroy()
	final.Parent = chests

	local _, size = final:GetBoundingBox()
	return ("%s: %d part(s), %.2f x %.2f x %.2f"):format(final.Name, #parts, size.X, size.Y, size.Z)
end

local function ensureGem(model)
	if model:FindFirstChild("Gem", true) then
		return nil
	end
	local base = model.PrimaryPart
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local gem = Instance.new("Part")
	gem.Name = "Gem"
	gem.Size = GEM_SIZE
	gem.Material = Enum.Material.Neon
	gem.Color = Color3.new(1, 1, 1)
	gem.TopSurface = Enum.SurfaceType.Smooth
	gem.BottomSurface = Enum.SurfaceType.Smooth
	gem.Anchored = false
	gem.CanCollide = false
	gem.CanTouch = false
	gem.CanQuery = false
	gem.Massless = true
	gem.CFrame = pivot * CFrame.new(0, size.Y * GEM_HEIGHT, -size.Z / 2 + GEM_INSET)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "WeldToBase"
	weld.Part0 = base
	weld.Part1 = gem
	weld.Parent = gem
	gem.Parent = model
	return model.Name .. ": added Gem"
end

local report = {}
for _, source in ipairs(chests:GetChildren()) do
	if source:IsA("Model") and source.Name:match("^Chest_") then
		table.insert(report, isPrepared(source) and (source.Name .. ": already prepared") or prepare(source))
	end
end
for _, model in ipairs(chests:GetChildren()) do
	if model:IsA("Model") and model.PrimaryPart then
		local added = ensureGem(model)
		if added then
			table.insert(report, added)
		end
	end
end
return #report > 0 and table.concat(report, "\n") or "No Chest_* models in Models.Treasures.Chests"
