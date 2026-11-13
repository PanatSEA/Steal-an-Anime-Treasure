-- DigClient: Pickaxe digging visuals (Phase 4). Visual only: the server decides every hit.
--   * Clicking with the Pickaxe swings it and asks the server to hit the nearest dig site.
--   * Each dig site shows a dirt mound with a buried chest. The visuals follow the site's
--     attributes (DigState, DigHits, DigHitsRequired, DigOwner, Rarity), so every player
--     sees the same thing and players who join late see the current state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))

local Dig = AnimeConfig.Dig
local World = AnimeConfig.World
local localPlayer = Players.LocalPlayer
local digHit = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DigHit")
local digSites = Workspace:WaitForChild(World.GameFolderName):WaitForChild(World.DigSitesFolderName)

local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local IDLE_EFFECT_SECONDS = 3.5
local BURIED_DEPTH = 1.05 -- studs below its resting height the chest starts (hit 1 and 2 each lift a third)
local BURIED_TILT = Vector2.new(10, 18) -- degrees (X, Z) so a lid corner pokes out of the mound
local FINAL_MOUND_SCALE = 0.45 -- mound size just before the last hit
local POP_HEIGHT = 3
local BEAM_HEIGHT = { Common = 6, Epic = 10, Legendary = 16, Secret = 24 }
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

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function sequence(a, b)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
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
	local rest = chest.PrimaryPart.Size.Y / 2
	local tilt = 1 - progress
	return CFrame.new(view.Ground + Vector3.new(0, rest - BURIED_DEPTH * (1 - progress), 0))
		* FACING
		* CFrame.Angles(math.rad(BURIED_TILT.X * tilt), 0, math.rad(BURIED_TILT.Y * tilt))
end

local function bossConfig(model)
	return AnimeConfig.Bosses[model:GetAttribute("BossId")]
end

-- Building -----------------------------------------------------------------------

local function clearVisuals(view)
	for _, key in ipairs({ "Mound", "Chest", "Beam" }) do
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
	TreasureModels.SetDecorative(chest, true)
	local rarity = view.Model:GetAttribute("Rarity")
	if rarity then
		TreasureModels.ApplyRarity(chest, rarity)
	end
	chest:PivotTo(chestPose(view, chest, progress))
	chest.Parent = view.Folder
	view.Chest = chest
end

local function showBeam(view, rarity)
	local rarityInfo = AnimeConfig.Rarities[rarity]
	if not rarityInfo then
		return
	end
	local height = BEAM_HEIGHT[rarity] or 8
	local beam = Instance.new("Part")
	beam.Name = "RarityBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(height, 1.6, 1.6)
	beam.CFrame = CFrame.new(view.Ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Material = Enum.Material.Neon
	beam.Color = rarityInfo.Color
	beam.Transparency = 1
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = rarityInfo.Color
	light.Range = 14
	light.Brightness = 2
	light.Parent = beam
	beam.Parent = view.Folder
	TweenService:Create(beam, TweenInfo.new(0.3), { Transparency = 0.55 }):Play()
	view.Beam = beam
end

local function fadeBeam(view)
	local beam = view.Beam
	view.Beam = nil
	if beam then
		TweenService:Create(beam, TweenInfo.new(1), { Transparency = 1 }):Play()
		Debris:AddItem(beam, 1.1)
	end
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
		local rarity = view.Model:GetAttribute("Rarity")
		if rarity then
			showBeam(view, rarity)
		end
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

local function flingChunks(view, count)
	if not view.Mound then
		return
	end
	local flung = 0
	for _, chunk in ipairs(view.Mound:GetDescendants()) do
		if flung >= count then
			break
		end
		if chunk:IsA("BasePart") and chunk.Name == "Chunk" then
			flung += 1
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
end

local function isMine(view)
	local _, _, _, owner = siteInfo(view.Model)
	return owner == localPlayer.UserId
end

local function playHit(view, hits, required)
	local boss = bossConfig(view.Model)
	view.Dust:Emit(28)
	flingChunks(view, 2)
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

local function playEmerge(view)
	local boss = bossConfig(view.Model)
	local rarity = view.Model:GetAttribute("Rarity")
	if not view.Chest then
		buildChest(view, 2 / 3)
	end
	view.Dust:Emit(40)
	flingChunks(view, 99)
	local mound = view.Mound
	view.Mound = nil
	if mound then
		scaleModel(mound, 0.01, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(mound, 0.3)
	end

	local chest = view.Chest
	if rarity then
		TreasureModels.ApplyRarity(chest, rarity)
		showBeam(view, rarity)
	end
	local rest = chestPose(view, chest, 1)
	local top = rest + Vector3.new(0, POP_HEIGHT, 0)
	moveChest(chest, chest:GetPivot(), top, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.25, function()
		moveChest(chest, top, rest, 0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	end)
	task.delay(0.15, function()
		local color = rarity and AnimeConfig.Rarities[rarity] and AnimeConfig.Rarities[rarity].Color or Color3.new(1, 1, 1)
		view.Sparkle.Color = ColorSequence.new(color)
		view.Sparkle:Emit(45)
	end)
	playSound(boss and boss.EmergeSoundId, view.Fx)
	if isMine(view) then
		shakeCamera(0.5, 0.35)
	end
end

local function playTaken(view)
	local chest = view.Chest
	view.Chest = nil
	if chest then
		scaleModel(chest, 0.01, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(chest, 0.25)
	end
	fadeBeam(view)
end

-- A new mound grows in (treasure respawned, or a claim lapsed and the dig reset).
local function playRespawn(view)
	clearVisuals(view)
	buildMound(view, 0.01)
	buildChest(view, 0)
	scaleModel(view.Mound, 1, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	view.Puff:Emit(8)
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
	local attachment = Instance.new("Attachment")
	attachment.Parent = fx

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
		Dust = emitter(attachment, {
			Texture = DUST_TEXTURE,
			Color = ColorSequence.new(Color3.fromRGB(140, 100, 60)),
			Size = sequence(1.2, 0.2),
			Transparency = sequence(0.2, 1),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -25, 0),
			RotSpeed = NumberRange.new(-90, 90),
		}),
		Puff = emitter(attachment, {
			Texture = DUST_TEXTURE,
			Color = ColorSequence.new(Color3.fromRGB(170, 135, 95)),
			Size = sequence(1.5, 2.5),
			Transparency = sequence(0.6, 1),
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 1, 0),
		}),
		Sparkle = emitter(attachment, {
			Texture = SPARKLE_TEXTURE,
			LightEmission = 1,
			Size = sequence(0.6, 0),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(6, 14),
			SpreadAngle = Vector2.new(180, 180),
		}),
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

-- Idle effect: a gentle dust puff and a faint sparkle so untouched mounds stand out.
task.spawn(function()
	while true do
		task.wait(IDLE_EFFECT_SECONDS)
		for _, view in pairs(views) do
			if view.Mound and view.State == "Buried" and view.Hits == 0 then
				view.Puff:Emit(5)
				view.Sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200))
				view.Sparkle:Emit(3)
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
