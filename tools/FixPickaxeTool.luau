-- Run in Studio (Edit mode, command bar) to apply the held-tool rules to StarterPack.Pickaxe.
-- Fixes the "character shakes and is hard to move with the Pickaxe equipped" bug:
--   * every BasePart: Anchored = false, CanCollide = false, Massless = true
--   * CanTouch = false on everything except Handle
--   * every part welded to Handle with a WeldConstraint (legacy Welds replaced, offsets kept)
--   * Grip set so the right hand holds the shaft a quarter of the way up, shaft pointing
--     up and ~20 degrees forward, clear of the legs, head and ground
--   * CanBeDropped = false (the Pickaxe lives in hotbar slot 1)
-- The server also re-applies the physics rules at runtime (InventoryService + HeldPhysics).

local tool = game:GetService("StarterPack"):FindFirstChild("Pickaxe")
assert(tool and tool:IsA("Tool"), "StarterPack.Pickaxe not found")
local handle = tool:FindFirstChild("Handle")
assert(handle and handle:IsA("BasePart"), "Pickaxe has no Handle")

local GRIP = CFrame.new(
	0.0593, 1.0669, -1.1548,
	0.997982, 0.007512, -0.063055,
	-0.054351, 0.614549, -0.787004,
	0.032838, 0.788842, 0.613717
)

-- Replace legacy joints to Handle with WeldConstraints, keeping each part where it is.
local offsets = {}
for _, joint in ipairs(tool:GetDescendants()) do
	if joint:IsA("JointInstance") and (joint.Part0 == handle or joint.Part1 == handle) then
		local other = joint.Part0 == handle and joint.Part1 or joint.Part0
		if other then
			offsets[other] = handle.CFrame:ToObjectSpace(other.CFrame)
		end
		joint:Destroy()
	end
end

local report = {}
for _, part in ipairs(tool:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.CanTouch = part == handle
		if part ~= handle then
			if offsets[part] then
				part.CFrame = handle.CFrame * offsets[part]
			end
			local welded = false
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") and (child.Part0 == handle or child.Part1 == handle) then
					welded = true
				end
			end
			if not welded then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "WeldToHandle"
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
		table.insert(report, part.Name)
	end
end

tool.Grip = GRIP
tool.CanBeDropped = false

return "Pickaxe fixed: " .. table.concat(report, ", ")
