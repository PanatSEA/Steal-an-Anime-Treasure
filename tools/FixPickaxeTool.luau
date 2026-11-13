-- Run in Studio (Edit mode, command bar) to apply the held-tool rules to StarterPack.Pickaxe.
-- Fixes the "character shakes and is hard to move with the Pickaxe equipped" bug:
--   * every BasePart: Anchored = false, CanCollide = false, Massless = true
--   * CanTouch = false on everything except Handle
--   * every part welded to Handle with a WeldConstraint (legacy Welds replaced, offsets kept)
--   * Grip is rotation only: the Handle (already on the shaft, near its bottom end) stays
--     centred in the hand, and the shaft stands straight up (90 degrees), clear of the
--     legs, head and ground
--   * Handle is invisible (it was a half-transparent red cube showing in the hand)
--   * CanBeDropped = false (the Pickaxe lives in hotbar slot 1)
-- The server also re-applies the physics rules at runtime (InventoryService + HeldPhysics).

local tool = game:GetService("StarterPack"):FindFirstChild("Pickaxe")
assert(tool and tool:IsA("Tool"), "StarterPack.Pickaxe not found")
local handle = tool:FindFirstChild("Handle")
assert(handle and handle:IsA("BasePart"), "Pickaxe has no Handle")

local GRIP = CFrame.new(
	0, 0, 0,
	0.996842622756958, -0.0028636548668146133, -0.07935161143541336,
	0.0069031077437102795, 0.998691201210022, 0.0506780706346035,
	0.07910263538360596, -0.051065847277641296, 0.9955577254295349
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
handle.Transparency = 1

return "Pickaxe fixed: " .. table.concat(report, ", ")
