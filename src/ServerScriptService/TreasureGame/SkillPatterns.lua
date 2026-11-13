-- SkillPatterns: boss skills keyed by AnimeConfig SkillPattern name.
-- Every pattern shows a ground telegraph first, waits TelegraphWarningSeconds,
-- then strikes. Add harder patterns for Boss_02 / Boss_03 here (e.g. several
-- circles at once, a line, a ring that closes in) and point SkillPattern at them.
--
-- ctx = {
--   Config        = boss config table,
--   BossModel     = Model,
--   TargetRoot    = target HumanoidRootPart,
--   EffectsFolder = Folder for telegraph parts,
--   OnPlayerHit   = function(player) called for each player struck,
-- }
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Zones = require(script.Parent.Zones)
local Sfx = require(script.Parent.Sfx)

local SkillPatterns = {}

local STRIKE_HEIGHT_TOLERANCE = 12
local STRIKE_FLASH_COLOR = Color3.fromRGB(255, 235, 200)

local function findGround(pos, ctx)
	local ignore = { ctx.BossModel, ctx.EffectsFolder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
	return result and result.Position or (pos - Vector3.new(0, 3, 0))
end

local function flatDisc(name, center, diameter, color, transparency)
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = transparency
	disc.Size = Vector3.new(0.2, diameter, diameter)
	disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return disc
end

-- Red warning circle whose fill grows until the strike lands.
local function circleStrike(ctx, center)
	local cfg = ctx.Config
	local color = AnimeConfig.GetColor(cfg.TelegraphColor)
	local radius = cfg.SkillRadiusStuds
	local diameter = radius * 2
	local warning = cfg.TelegraphWarningSeconds

	local telegraph = Instance.new("Model")
	telegraph.Name = "Telegraph_" .. cfg.BossId
	local ring = flatDisc("Ring", center + Vector3.new(0, 0.1, 0), diameter, color, 0.55)
	ring.Parent = telegraph
	local fill = flatDisc("Fill", center + Vector3.new(0, 0.15, 0), 0.5, color, 0.2)
	fill.Parent = telegraph
	telegraph.Parent = ctx.EffectsFolder

	Sfx.Play(cfg.TelegraphSoundId, ring)
	TweenService:Create(fill, TweenInfo.new(warning, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.2, diameter, diameter),
	}):Play()
	task.wait(warning)

	-- Strike
	fill.Color = STRIKE_FLASH_COLOR
	fill.Transparency = 0
	Sfx.Play(cfg.SkillHitSoundId, ring)

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flatDistance <= radius
				and math.abs(offset.Y) <= STRIKE_HEIGHT_TOLERANCE
				and not Zones.IsInSafeZone(root.Position)
			then
				humanoid:TakeDamage(cfg.SkillDamage)
				ctx.OnPlayerHit(player)
			end
		end
	end

	for _, part in ipairs({ ring, fill }) do
		TweenService:Create(part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end
	Debris:AddItem(telegraph, 0.5)
end

-- Boss_01: one circle dropped on the target's current position.
function SkillPatterns.CircleTelegraph(ctx)
	circleStrike(ctx, findGround(ctx.TargetRoot.Position, ctx))
end

return SkillPatterns
