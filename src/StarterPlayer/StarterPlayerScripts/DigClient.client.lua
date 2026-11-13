-- DigClient: Pickaxe digging visuals. Visual only: the server decides every hit.
--   * Clicking with the Pickaxe swings it and asks the server to hit the nearest dig site.
--   * Each dig site shows a rock mound with a buried chest. The visuals follow the site's
--     attributes (DigState, DigHits, DigHitsRequired, DigOwner, Rarity), so every player
--     sees the same thing and players who join late see the current state.
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
local BURIED_DEPTH_FRACTION = 0.45 -- the chest starts this much of its height underground (hits 1 and 2 each lift a third)
local BURIED_TILT = Vector2.new(10, 18) -- degrees (X, Z) so a lid corner pokes out of the mound
local FINAL_MOUND_SCALE = 0.45 -- mound size just before the last hit
local POP_HEIGHT = 3
local POP_SECONDS, FALL_SECONDS = 0.25, 0.6
local FIRST_BOUNCE = 1 / 2.75 -- Bounce easing first touches the ground this far into the fall
local CHUNKS_PER_HIT = 3
local BREAKABLE = { Chunk = true, Crystal = true } -- mound parts that break off on hits
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

local function moundScale(hits, required)
	if required <= 1 then
		return 1
	end
	return 1 - (1 - FINAL_MOUND_SCALE) * math.clamp(hits / (required - 1), 0, 1)
end

-- Chest pose: progress 0 = buried with a corner showing, 1 = resting on the ground.
local function chestPose(view, chest, progress)
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

-- Where the pickaxe meets the rock: the side of the mound facing the digger, near the top,
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
		local _, size = view.Mound:GetBoundingBox()
		radius, height = size.X * 0.22, size.Y * 0.55
	end
	local point = view.Ground + flat * radius + Vector3.new(0, height, 0)
	return CFrame.lookAt(point, point + (flat + Vector3.yAxis).Unit)
end

local function breakableParts(mound)
	local parts = {}
	for _, part in ipairs(mound:GetDescendants()) do
		if part:IsA("BasePart") and BREAKABLE[part.Name] then
			table.insert(parts, part)
		end
	end
	return parts
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

local function buildMound(view, scale)
	local mound = TreasureModels.DirtMound()
	TreasureModels.SetDecorative(mound, true)
	mound:PivotTo(CFrame.new(view.Ground) * FACING)
	if scale ~= 1 then
		mound:ScaleTo(math.max(scale, 0.01))
	end
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
	chest:PivotTo(chestPose(view, chest, progress))
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
	buildMound(view, moundScale(hits, required))
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

-- Breaks rock chunks and blue crystals off the mound (random ones, up to `count`).
local function flingChunks(view, count)
	if not view.Mound then
		return
	end
	local parts = breakableParts(view.Mound)
	for i = 1, math.min(count, #parts) do
		local pick = math.random(i, #parts)
		parts[i], parts[pick] = parts[pick], parts[i]
		local chunk = parts[i]
		local piece = chunk:Clone()
		piece.Anchored = false
		piece.CanCollide = false
		piece.Parent = view.Folder
		local outward = (chunk.Position - view.Ground) * Vector3.new(1, 0, 1)
		outward = outward.Magnitude > 0.1 and outward.Unit or Vector3.new(1, 0, 0)
		piece.AssemblyLinearVelocity = outward * math.random(10, 18) + Vector3.new(0, math.random(18, 28), 0)
		piece.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		TweenService:Create(piece, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		Debris:AddItem(piece, 1.3)
		chunk:Destroy()
	end
end

local function isMine(view)
	local _, _, _, owner = siteInfo(view.Model)
	return owner == localPlayer.UserId
end

-- Hits 1 and 2.
local function playHit(view, hits, required)
	local boss = bossConfig(view.Model)
	VfxPlayer.PlayPreset(ChestFxPresets.DigHit, impactCFrame(view))
	flingChunks(view, CHUNKS_PER_HIT)
	if view.Mound then
		scaleModel(view.Mound, moundScale(hits, required), 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end
	if view.Chest then
		moveChest(view.Chest, view.Chest:GetPivot(), chestPose(view, view.Chest, hits / required), 0.35,
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
	flingChunks(view, 99)
	local mound = view.Mound
	view.Mound = nil
	if mound then
		scaleModel(mound, 0.01, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(mound, 0.3)
	end

	local chest = view.Chest
	if rarity then
		TreasureModels.ApplyRarityGlow(chest, rarity, true)
	end
	local rest = chestPose(view, chest, 1)
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
	buildMound(view, 0.01)
	buildChest(view, 0)
	scaleModel(view.Mound, 1, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
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
				for _, part in ipairs(breakableParts(view.Mound)) do
					if part.Name == "Crystal" then
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
