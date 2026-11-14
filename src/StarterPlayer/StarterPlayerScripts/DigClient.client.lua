-- DigClient: Pickaxe digging visuals. Visual only: the server decides every hit.
--   * Clicking with the Pickaxe swings it and asks the server to hit the nearest dig site.
--   * Each dig site shows a layered block mound (Models/Treasures/DirtMound, built by
--     tools/BuildDirtMound.luau) with the chest poking out of the top. The visuals follow the
--     site's attributes (DigState, DigHits, DigHitsRequired, DigOwner, Rarity), so every player
--     sees the same thing and players who join late see the current state.
--   * Each hit peels a layer off (blocks tagged DigLayer 1 = top), the blocks fly off and fade,
--     and the chest rises to the mound's next ChestPose. The last hit bursts the rest outward
--     and the chest pops out. The mound and flying blocks are local copies; the server only
--     counts hits.
--   * Effects come from ReplicatedStorage/VFX via VfxPlayer; tune them in ChestFxPresets:
--     DigHit on hits 1-2, ChestBurst (+ EmergeSoundId) on hit 3, ChestLand when the chest lands,
--     IdleSparkle while the emerged chest waits to be picked up, MoundTwinkle/MoundPuff on mounds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local VfxPlayer = require(Shared:WaitForChild("VfxPlayer"))
local ChestFxPresets = require(Shared:WaitForChild("ChestFxPresets"))

local Dig = AnimeConfig.Dig
local World = AnimeConfig.World
local localPlayer = Players.LocalPlayer
local digHit = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DigHit")
local digSites = Workspace:WaitForChild(World.GameFolderName):WaitForChild(World.DigSitesFolderName)

local TWINKLE_SECONDS = 1.5 -- a crystal on an untouched mound twinkles this often
-- Fallback chest pose for a mound without ChestPose attributes (e.g. the placeholder).
local BURIED_DEPTH_FRACTION = 0.45 -- the chest starts this much of its height underground
local BURIED_TILT = Vector2.new(10, 18) -- degrees (X, Z) so a lid corner pokes out of the mound
local POP_HEIGHT = 3
local POP_SECONDS, FALL_SECONDS = 0.25, 0.6
local FIRST_BOUNCE = 1 / 2.75 -- Bounce easing first touches the ground this far into the fall
-- Blocks knocked off the mound: scripted arcs (no physics), they land on the ground and fade.
local FLY_SECONDS = 1 -- fade-out time
local FLY_GRAVITY = 70 -- studs/s², lighter than the world's so the blocks hang in the air a moment
local HIT_FLING = { out = NumberRange.new(8, 14), up = NumberRange.new(16, 24) } -- studs/s, hits 1-2
local BURST_FLING = { out = NumberRange.new(14, 24), up = NumberRange.new(20, 30) } -- last hit
local FLY_SPIN = 9 -- max spin, radians/s per axis
local FACING = CFrame.Angles(0, math.rad(-90), 0) -- chest front faces +X, toward the lobby

local views = {} -- [dig site Model] = view

-- Helpers ------------------------------------------------------------------------

local function tweenNumber(from, to, seconds, style, direction, onStep)
	local value = Instance.new("NumberValue")
	value.Value = from
	local connection = value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = to })
	tween.Completed:Connect(function()
		connection:Disconnect()
		value:Destroy()
	end)
	onStep(from)
	tween:Play()
	return tween
end

local function playSound(soundId, parent)
	if AnimeConfig.IsPlaceholderAsset(soundId) then
		return -- TODO(asset): sound not made yet
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function shakeCamera(strength, seconds)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= seconds or not humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local k = strength * (1 - elapsed / seconds)
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k, (math.random() - 0.5) * k)
	end)
end

-- Presets are aimed with LookVector = main direction; for the chest that is straight up.
local function aimUp(position)
	return CFrame.lookAt(position, position + Vector3.yAxis, Vector3.zAxis)
end

local function siteInfo(model)
	return model:GetAttribute("DigState") or "Locked",
		model:GetAttribute("DigHits") or 0,
		math.max(model:GetAttribute("DigHitsRequired") or 3, 1),
		model:GetAttribute("DigOwner") or 0
end

-- How many mound layers are gone after `hits`: one per hit from the top, but the bottom layer
-- stays until the last hit (with more hits than layers some hits remove nothing).
local function layersGone(hits, required, layers)
	if required <= 1 or layers <= 1 then
		return 0
	end
	return math.clamp(math.floor(hits * (layers - 1) / (required - 1)), 0, layers - 1)
end

local function moundPivot(view)
	return CFrame.new(view.Ground) * FACING
end

-- Where the chest sits with `gone` layers removed, from the mound's ChestPose<gone> attribute.
-- `progress` (0 = buried, 1 = resting on the ground) is the fallback for mounds without one.
local function chestPose(view, chest, gone, progress)
	local pose = view.Poses and view.Poses[gone]
	if pose and progress < 1 then
		return moundPivot(view) * pose
	end
	local rest = TreasureModels.PivotHeight(chest) -- 0 when the chest's pivot is at its bottom
	local depth = TreasureModels.Height(chest) * BURIED_DEPTH_FRACTION
	local tilt = 1 - progress
	return CFrame.new(view.Ground + Vector3.new(0, rest - depth * (1 - progress), 0))
		* FACING
		* CFrame.Angles(math.rad(BURIED_TILT.X * tilt), 0, math.rad(BURIED_TILT.Y * tilt))
end

local function bossConfig(model)
	return AnimeConfig.Bosses[model:GetAttribute("BossId")]
end

local function rarityTint(view)
	return ChestFxPresets.RarityTint[view.Model:GetAttribute("Rarity")]
end

-- Mound parts on layer `layer` or above (DigLayer <= layer); every part but Root when nil.
local function layerParts(mound, layer)
	local parts = {}
	for _, part in ipairs(mound:GetDescendants()) do
		if part:IsA("BasePart") and part ~= mound.PrimaryPart then
			local tag = part:GetAttribute("DigLayer")
			if layer == nil or (tag and tag <= layer) then
				table.insert(parts, part)
			end
		end
	end
	return parts
end

-- Where the pickaxe meets the rock: the edge of the top remaining layer facing the digger,
-- aimed back toward the digger and up so the spray flies out of the rock at them.
local function impactCFrame(view)
	local _, _, _, owner = siteInfo(view.Model)
	local digger = Players:GetPlayerByUserId(owner)
	local root = digger and digger.Character and digger.Character:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or Workspace.CurrentCamera.CFrame.Position
	local flat = (from - view.Ground) * Vector3.new(1, 0, 1)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
	local radius, height = 2, 2.4
	if view.Mound then
		local top, reach = 0, 0
		for _, part in ipairs(layerParts(view.Mound, (view.Gone or 0) + 1)) do
			if part:GetAttribute("DigLayer") == (view.Gone or 0) + 1 and part.CanCollide then
				local offset = part.Position - view.Ground
				top = math.max(top, offset.Y + part.Size.Y / 2)
				reach = math.max(reach, offset:Dot(flat) + math.min(part.Size.X, part.Size.Z) / 2)
			end
		end
		if top > 0 then
			radius, height = reach, top - 0.3
		else -- a mound without layers
			local _, size = view.Mound:GetBoundingBox()
			radius, height = size.X * 0.22, size.Y * 0.55
		end
	end
	local point = view.Ground + flat * radius + Vector3.new(0, height, 0)
	return CFrame.lookAt(point, point + (flat + Vector3.yAxis).Unit)
end

-- Loops ----------------------------------------------------------------------------

local function stopIdle(view)
	if view.StopLoop then
		view.StopLoop()
		view.StopLoop = nil
	end
end

-- IdleSparkle around the emerged chest while it waits to be picked up.
local function startIdle(view)
	stopIdle(view)
	local chest = view.Chest
	local root = chest and chest.PrimaryPart
	if not root then
		return
	end
	local centre = (chest:GetBoundingBox()).Position
	view.StopLoop = VfxPlayer.LoopPreset(ChestFxPresets.IdleSparkle, root, {
		offset = root.CFrame:PointToObjectSpace(centre),
		tint = rarityTint(view),
	})
end

-- Building -----------------------------------------------------------------------

local function clearVisuals(view)
	stopIdle(view)
	for _, key in ipairs({ "Mound", "Chest" }) do
		if view[key] then
			view[key]:Destroy()
			view[key] = nil
		end
	end
end

-- Builds the mound with the layers already dug through (`hits` so far) left out.
local function buildMound(view, hits, required)
	local mound = TreasureModels.DirtMound()
	local layers, poses = 1, {}
	for _, part in ipairs(mound:GetDescendants()) do
		if part:IsA("BasePart") then
			local layer = part:GetAttribute("DigLayer")
			layers = math.max(layers, layer or 1)
			-- Body blocks keep the model's CanCollide (players can't walk through the pile);
			-- loose blocks, crystals and a placeholder mound without layers are decoration only.
			part.Anchored = true
			part.CanTouch = false
			if not layer then
				part.CanCollide = false
			end
			if not part.CanCollide then
				part.CanQuery = false
			end
		end
	end
	for gone = 0, layers - 1 do
		poses[gone] = mound:GetAttribute("ChestPose" .. gone)
	end
	view.Layers, view.Poses = layers, poses
	view.Gone = layersGone(hits, required, layers)
	for _, part in ipairs(layerParts(mound, view.Gone)) do
		part:Destroy()
	end
	mound:PivotTo(moundPivot(view))
	mound.Parent = view.Folder
	view.Mound = mound
end

local function buildChest(view, progress)
	local chest = TreasureModels.Chest()
	local rarity = view.Model:GetAttribute("Rarity")
	if rarity then
		TreasureModels.ApplyRarityGlow(chest, rarity, true)
	end
	TreasureModels.SetDecorative(chest, true)
	chest:PivotTo(chestPose(view, chest, view.Gone or 0, progress))
	chest.Parent = view.Folder
	view.Chest = chest
end

-- Draws the current state with no animation (first load, late join).
local function render(view)
	clearVisuals(view)
	local state, hits, required = siteInfo(view.Model)
	if state == "Taken" then
		return
	end
	if state == "Emerged" then
		buildChest(view, 1)
		startIdle(view)
		return
	end
	buildMound(view, hits, required)
	buildChest(view, hits / required)
end

-- Animations -----------------------------------------------------------------------

local function moveChest(chest, fromCFrame, toCFrame, seconds, style, direction)
	tweenNumber(0, 1, seconds, style, direction, function(alpha)
		if chest.Parent then
			chest:PivotTo(fromCFrame:Lerp(toCFrame, alpha))
		end
	end)
end

local function scaleModel(model, to, seconds, style, direction)
	tweenNumber(model:GetScale(), to, seconds, style, direction, function(scale)
		if model.Parent then
			model:ScaleTo(math.max(scale, 0.01))
		end
	end)
end

local function randomIn(range)
	return range.Min + math.random() * (range.Max - range.Min)
end

-- Where a flying block is `t` seconds after it was knocked off: a gravity arc that stops
-- (and stops spinning) when it lands on the ground.
local function flightCFrame(fly, t)
	local tt = math.min(t, fly.LandAt)
	local position = fly.Start.Position + fly.Velocity * tt - Vector3.new(0, 0.5 * FLY_GRAVITY * tt * tt, 0)
	local spin = fly.Spin * tt
	return CFrame.new(position) * CFrame.Angles(spin.X, spin.Y, spin.Z) * fly.Start.Rotation
end

-- Knocks mound parts off: they fly outward and up, spin, land and fade out. The mound is
-- already a local copy, so the parts themselves fly (nothing is replicated).
local function flingParts(view, parts, fling)
	local flights = {}
	local fade = TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in ipairs(parts) do
		local outward = (part.Position - view.Ground) * Vector3.new(1, 0, 1)
		if outward.Magnitude < 0.3 then
			local angle = math.random() * math.pi * 2
			outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		end
		local velocity = outward.Unit * randomIn(fling.out) + Vector3.new(0, randomIn(fling.up), 0)
		-- lands when its centre comes down to about half its height above the ground
		local drop = part.Position.Y - (view.Ground.Y + math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2)
		local landAt = (velocity.Y + math.sqrt(velocity.Y ^ 2 + 2 * FLY_GRAVITY * math.max(drop, 0))) / FLY_GRAVITY
		local spin = (Vector3.new(math.random(), math.random(), math.random()) * 2 - Vector3.one) * FLY_SPIN
		table.insert(flights, { Part = part, Start = part.CFrame, Velocity = velocity, Spin = spin, LandAt = landAt })
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = view.Folder
		TweenService:Create(part, fade, { Transparency = 1 }):Play()
		for _, light in ipairs(part:GetChildren()) do
			if light:IsA("Light") then
				TweenService:Create(light, fade, { Brightness = 0 }):Play()
			end
		end
	end
	if #flights == 0 then
		return
	end
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		for _, fly in ipairs(flights) do
			if fly.Part.Parent then
				fly.Part.CFrame = flightCFrame(fly, t)
			end
		end
		if t >= FLY_SECONDS then
			connection:Disconnect()
			for _, fly in ipairs(flights) do
				fly.Part:Destroy()
			end
		end
	end)
end

local function isMine(view)
	local _, _, _, owner = siteInfo(view.Model)
	return owner == localPlayer.UserId
end

-- Hits before the last: the top remaining layer flies off and the chest rises.
local function playHit(view, hits, required)
	local boss = bossConfig(view.Model)
	VfxPlayer.PlayPreset(ChestFxPresets.DigHit, impactCFrame(view))
	if view.Mound then
		view.Gone = layersGone(hits, required, view.Layers)
		flingParts(view, layerParts(view.Mound, view.Gone), HIT_FLING)
	end
	if view.Chest then
		moveChest(view.Chest, view.Chest:GetPivot(), chestPose(view, view.Chest, view.Gone or 0, hits / required), 0.35,
			Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end
	playSound(boss and boss.HitSoundId, view.Fx)
	if isMine(view) then
		shakeCamera(0.35, 0.25)
	end
end

-- Hit 3: the chest bursts out, pops up and bounces down.
local function playEmerge(view)
	local boss = bossConfig(view.Model)
	local rarity = view.Model:GetAttribute("Rarity")
	if not view.Chest then
		buildChest(view, 2 / 3)
	end
	VfxPlayer.PlayPreset(ChestFxPresets.ChestBurst, aimUp(view.Ground + Vector3.new(0, 0.5, 0)))
	playSound(boss and boss.EmergeSoundId, view.Fx)
	local mound = view.Mound
	view.Mound = nil
	if mound then
		flingParts(view, layerParts(mound, nil), BURST_FLING) -- everything left bursts outward
		mound:Destroy()
	end

	local chest = view.Chest
	if rarity then
		TreasureModels.ApplyRarityGlow(chest, rarity, true)
	end
	local rest = chestPose(view, chest, 0, 1)
	local top = rest + Vector3.new(0, POP_HEIGHT, 0)
	moveChest(chest, chest:GetPivot(), top, POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(POP_SECONDS, function()
		moveChest(chest, top, rest, FALL_SECONDS, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	end)
	task.delay(POP_SECONDS + FALL_SECONDS * FIRST_BOUNCE, function()
		if view.Chest == chest and chest.Parent then
			VfxPlayer.PlayPreset(ChestFxPresets.ChestLand, aimUp(view.Ground))
		end
	end)
	task.delay(POP_SECONDS + FALL_SECONDS, function()
		if view.Chest == chest and chest.Parent then
			startIdle(view)
		end
	end)
	if isMine(view) then
		shakeCamera(0.5, 0.35)
	end
end

-- Picked up: the chest shrinks away (it reappears on the owner's plot).
local function playTaken(view)
	stopIdle(view)
	local chest = view.Chest
	view.Chest = nil
	if chest then
		scaleModel(chest, 0.01, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(chest, 0.25)
	end
end

-- A new mound grows in (treasure respawned, or a claim lapsed and the dig reset).
local function playRespawn(view)
	clearVisuals(view)
	buildMound(view, 0, 1)
	buildChest(view, 0)
	-- The full mound grows back from the ground with the chest in it.
	local mound, chest = view.Mound, view.Chest
	local pose = moundPivot(view):ToObjectSpace(chest:GetPivot()) -- chest relative to the mound
	tweenNumber(0.01, 1, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(scale)
		scale = math.max(scale, 0.01)
		if mound.Parent then
			mound:ScaleTo(scale)
		end
		if chest.Parent then
			chest:ScaleTo(scale)
			chest:PivotTo(moundPivot(view) * CFrame.new(pose.Position * scale) * pose.Rotation)
		end
	end)
	VfxPlayer.PlayPreset(ChestFxPresets.MoundPuff, aimUp(view.Ground + Vector3.new(0, 0.5, 0)))
end

local function updateLabel(view)
	local state, hits, required, owner = siteInfo(view.Model)
	if state ~= "Buried" then
		view.Label.Text = ""
	elseif owner == 0 then
		view.Label.Text = "Dig with your Pickaxe!"
	elseif owner == localPlayer.UserId then
		view.Label.Text = ("Hit %d/%d"):format(hits, required)
	else
		local digger = Players:GetPlayerByUserId(owner)
		view.Label.Text = ("%s is digging"):format(digger and digger.DisplayName or "Someone")
	end
end

local function sync(view)
	local state, hits, required = siteInfo(view.Model)
	local previousState, previousHits = view.State, view.Hits
	view.State, view.Hits = state, hits
	updateLabel(view)

	if previousState == nil then
		render(view)
	elseif state == "Emerged" and previousState ~= "Emerged" then
		playEmerge(view)
	elseif state == "Taken" and previousState ~= "Taken" then
		playTaken(view)
	elseif state == "Buried" or state == "Locked" then
		if previousState == "Taken" or previousState == "Emerged" then
			playRespawn(view)
		elseif hits > previousHits and hits < required then
			playHit(view, hits, required)
		elseif hits < previousHits then
			playRespawn(view)
		end
	end
end

-- Site setup -------------------------------------------------------------------------

local function addSite(model)
	if views[model] or not model:IsA("Model") then
		return
	end
	local anchor = model:WaitForChild("DigMound", 10)
	if not anchor then
		return
	end
	local ground = anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0)

	local folder = Instance.new("Folder")
	folder.Name = "DigVisuals_" .. model.Name
	folder.Parent = Workspace

	local fx = Instance.new("Part")
	fx.Name = "Fx"
	fx.Size = Vector3.new(1, 1, 1)
	fx.Transparency = 1
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.CFrame = CFrame.new(ground + Vector3.new(0, 1.8, 0))
	fx.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 30)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.MaxDistance = 60
	billboard.Parent = fx
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	local view = {
		Model = model,
		Ground = ground,
		Folder = folder,
		Fx = fx,
		Label = label,
	}
	views[model] = view

	local queued = false
	local function queueSync()
		if queued then
			return
		end
		queued = true
		task.defer(function() -- attributes set together on the server arrive as one update
			queued = false
			if views[model] then
				sync(view)
			end
		end)
	end
	for _, attribute in ipairs({ "DigState", "DigHits", "DigOwner", "Rarity" }) do
		model:GetAttributeChangedSignal(attribute):Connect(queueSync)
	end
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			stopIdle(view)
			views[model] = nil
			folder:Destroy()
		end
	end)
	sync(view)
end

for _, model in ipairs(digSites:GetChildren()) do
	task.spawn(addSite, model)
end
digSites.ChildAdded:Connect(addSite)

-- Untouched mounds: one of their blue crystals twinkles now and then so they stand out.
task.spawn(function()
	while true do
		task.wait(TWINKLE_SECONDS)
		for _, view in pairs(views) do
			if view.Mound and view.State == "Buried" and view.Hits == 0 then
				local crystals = {}
				for _, part in ipairs(view.Mound:GetDescendants()) do
					if part.Name == "Crystal" and part:IsA("BasePart") then
						table.insert(crystals, part)
					end
				end
				if #crystals > 0 then
					local crystal = crystals[math.random(#crystals)]
					local tip = crystal.Position + crystal.CFrame.UpVector * crystal.Size.Y * 0.5
					VfxPlayer.PlayPreset(ChestFxPresets.MoundTwinkle, CFrame.new(tip))
				end
			end
		end
	end
end)

-- Pickaxe ------------------------------------------------------------------------------

local lastSwing = 0
local baseGrips = setmetatable({}, { __mode = "k" })
local swingTracks = setmetatable({}, { __mode = "k" })

local function nearestSite(root)
	local best, bestDistance
	for model, view in pairs(views) do
		local distance = (root.Position - (view.Ground + Vector3.new(0, 1, 0))).Magnitude
		if distance <= Dig.MaxHitDistance and model:GetAttribute("DigState") == "Buried"
			and (not best or distance < bestDistance)
		then
			best, bestDistance = model, distance
		end
	end
	return best
end

-- Procedural swing on the Tool's grip (used until SwingAnimationId is set).
local function proceduralSwing(tool)
	local base = baseGrips[tool]
	if not base then
		base = tool.Grip
		baseGrips[tool] = base
	end
	tweenNumber(0, 1, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
		tool.Grip = base * CFrame.Angles(math.rad(-80 * alpha), 0, 0)
	end)
	task.delay(0.12, function()
		tweenNumber(1, 0, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha)
			tool.Grip = base * CFrame.Angles(math.rad(-80 * alpha), 0, 0)
		end)
	end)
end

local function playSwing(tool, humanoid)
	if not AnimeConfig.IsPlaceholderAsset(Dig.SwingAnimationId) then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local track = swingTracks[humanoid]
			if not track then
				local animation = Instance.new("Animation")
				animation.AnimationId = Dig.SwingAnimationId
				track = animator:LoadAnimation(animation)
				swingTracks[humanoid] = track
			end
			track:Play()
			return
		end
	end
	proceduralSwing(tool)
end

local hookedTools = setmetatable({}, { __mode = "k" })

local function hookTool(tool)
	if hookedTools[tool] or not tool:IsA("Tool") or tool.Name ~= Dig.ToolName then
		return
	end
	hookedTools[tool] = true
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwing < Dig.SwingCooldownSeconds then
			return
		end
		lastSwing = now
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then
			return
		end
		playSwing(tool, humanoid)
		local site = nearestSite(root)
		if site then
			local owner = site:GetAttribute("DigOwner") or 0
			if owner == 0 or owner == localPlayer.UserId then
				digHit:FireServer(site) -- the server checks everything and may ignore it
			end
		end
	end)
end

local function watchCharacter(character)
	for _, child in ipairs(character:GetChildren()) do
		hookTool(child)
	end
	character.ChildAdded:Connect(hookTool)
end

localPlayer.CharacterAdded:Connect(watchCharacter)
if localPlayer.Character then
	watchCharacter(localPlayer.Character)
end
