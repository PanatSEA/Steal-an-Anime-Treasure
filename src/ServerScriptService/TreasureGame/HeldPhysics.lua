-- HeldPhysics: rules for anything a character holds or carries (the Pickaxe, carried chests).
-- Held parts must never push the character around, so every part is:
--   Anchored = false, CanCollide = false, Massless = true,
--   CanTouch = false (except the root when keepRootTouch, e.g. a Tool's Handle),
--   and welded to the root with a WeldConstraint so nothing hangs loose.
local HeldPhysics = {}

-- Parts already joined to root by any weld (WeldConstraint or legacy Weld/Motor).
local function weldedToRoot(container, root)
	local welded = {}
	for _, joint in ipairs(container:GetDescendants()) do
		if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
			if joint.Part0 == root and joint.Part1 then
				welded[joint.Part1] = true
			elseif joint.Part1 == root and joint.Part0 then
				welded[joint.Part0] = true
			end
		end
	end
	return welded
end

function HeldPhysics.Apply(container, root, keepRootTouch)
	local welded = weldedToRoot(container, root)
	for _, part in ipairs(container:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CanTouch = keepRootTouch == true and part == root
			if part ~= root and not welded[part] then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "WeldToRoot"
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end

return HeldPhysics
