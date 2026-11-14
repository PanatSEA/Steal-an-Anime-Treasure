-- ChestFx: chest VFX on plots (client, visual only; the server decides everything).
--   * ChestLand when a chest lands on a plot (the server stamps new chests with PlacedAt, so
--     chests that were already there when you joined, or that stream back in, don't replay it).
--   * IdleSparkle loop while a chest's unlock timer runs, ReadyToOpen loop once it can be opened.
--     Loops stop when the chest is opened or removed.
--   * Opening (about 0.6 s; chests have no lid): the chest squashes (scale 1 -> 1.15 -> 0 about
--     its centre) and the rarity's opening bursts out as it collapses (RarityFx[rarity].Open,
--     plus the thin white light beam for OpenBeam rarities and, for Secret, a brief red
--     screen-edge flash for the chest's owner). Then the character pops out of the chest in an
--     arc and lands on its plot slot with a dust ring. The server spawns the character when the
--     chest is gone and stamps it with PopFrom (the chest's centre) and PopAt.
-- Effects come from ReplicatedStorage/VFX via VfxPlayer; tune them in ChestFxPresets. Sounds come from
-- AudioConfig (3D at the chest): ChestLand, Open_<Rarity>, CharacterAppear, then the CashTick coin
-- (once per new character; income itself is silent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local VfxPlayer = require(Shared:WaitForChild("VfxPlayer"))
local ChestFxPresets = require(Shared:WaitForChild("ChestFxPresets"))
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))

local treasureFx = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("TreasureFx")

-- Opening timeline (the server's AnimeConfig.Chest.OpenAnimationSeconds = SQUASH_GROW + SQUASH_SHRINK):
local SQUASH_PEAK = 1.15 -- the chest swells to this scale...
local SQUASH_GROW_SECONDS = 0.1
local SQUASH_SHRINK_SECONDS = 0.15 -- ...then collapses to nothing; the burst plays as it collapses
local CHARACTER_POP_SECONDS = 0.35 -- the character's arc from the chest to its slot
local CHARACTER_POP_HEIGHT = 3 -- studs above the straight line at the top of the arc
local CHARACTER_POP_START_SCALE = 0.2
local CHARACTER_POP_WINDOW = 2 -- characters spawned longer ago than this (e.g. on join) don't pop
local SCREEN_EDGE = 0.2 -- the screen-edge flash covers this fraction of the screen from each edge
local BEAM_HEIGHT = 22
local BEAM_SECONDS = 1.3
local PROMPT_WAIT_SECONDS = 5
local LAND_WINDOW_SECONDS = 2 -- chests placed less than this long ago get the landing effect

local chests = {} -- [chest Model] = { state = "Idle" | "Ready" | nil, stop = fn?, opened = bool }
local popCharacter -- defined with the opening code below

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
end

-- Presets are aimed with LookVector = main direction; for chests that is straight up.
local function aimUp(position)
	return CFrame.lookAt(position, position + Vector3.yAxis, Vector3.zAxis)
end

local function chestCentre(model)
	local boxCFrame = model:GetBoundingBox()
	return boxCFrame.Position
end

local function chestBase(model)
	return (model:GetPivot() * CFrame.new(0, -TreasureModels.PivotHeight(model), 0)).Position
end

local function rarityTint(model)
	local tints = ChestFxPresets.RarityTint
	return tints[model:GetAttribute("Rarity")] or tints.Common
end

local function justPlaced(model)
	local placedAt = model:GetAttribute("PlacedAt")
	return typeof(placedAt) == "number" and Workspace:GetServerTimeNow() - placedAt < LAND_WINDOW_SECONDS
end

-- Loops ----------------------------------------------------------------------------

local function setLoop(model, state)
	local entry = chests[model]
	if not entry or entry.state == state then
		return
	end
	if entry.stop then
		entry.stop()
		entry.stop = nil
	end
	entry.state = state
	local preset = (state == "Ready" and ChestFxPresets.ReadyToOpen) or (state == "Idle" and ChestFxPresets.IdleSparkle) or nil
	local root = model.PrimaryPart
	if preset and root then
		entry.stop = VfxPlayer.LoopPreset(preset, root, {
			offset = root.CFrame:PointToObjectSpace(chestCentre(model)), -- centre of the chest
			tint = rarityTint(model),
		})
	end
end

local function findPrompt(model)
	local deadline = os.clock() + PROMPT_WAIT_SECONDS
	repeat
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			return prompt
		end
		task.wait(0.1)
	until os.clock() > deadline or not model.Parent
	return nil
end

local function watchChest(model)
	if chests[model] or not model.Parent then
		return
	end
	local entry = { state = nil, stop = nil, opened = false }
	chests[model] = entry

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			setLoop(model, nil)
			chests[model] = nil
		end
	end)

	if justPlaced(model) then
		VfxPlayer.PlayPreset(ChestFxPresets.ChestLand, aimUp(chestBase(model)))
		AudioConfig.Play("ChestLand", chestBase(model))
	end

	local prompt = findPrompt(model)
	if not prompt or chests[model] ~= entry then
		return
	end
	local function update()
		if entry.opened or model:GetAttribute("Opening") then
			setLoop(model, nil)
		elseif prompt:GetAttribute("Ready") then
			setLoop(model, "Ready")
		else
			setLoop(model, "Idle")
		end
	end
	prompt:GetAttributeChangedSignal("Ready"):Connect(update)
	model:GetAttributeChangedSignal("Opening"):Connect(update)
	update()
end

-- Plot chests are models named "Chest_<Rarity>" under the plots folder.
local function isPlotChest(instance)
	return instance:IsA("Model") and instance.Name:match("^Chest_") ~= nil
end

local plotsRoot = Workspace
for _, name in ipairs(AnimeConfig.World.PlotsPath) do
	plotsRoot = plotsRoot:WaitForChild(name)
end
for _, descendant in ipairs(plotsRoot:GetDescendants()) do
	if isPlotChest(descendant) then
		task.spawn(watchChest, descendant)
	end
end
plotsRoot.DescendantAdded:Connect(function(descendant)
	if isPlotChest(descendant) then
		task.defer(watchChest, descendant) -- deferred: let the server's layout position arrive first
	elseif descendant:IsA("Model") and descendant:GetAttribute("PopFrom") ~= nil then
		task.defer(popCharacter, descendant) -- a character that just came out of a chest
	end
end)

-- Opening ------------------------------------------------------------------------

-- Thin white light beam shooting up out of the chest (a Beam, so it always faces the camera).
local function lightBeam(base)
	local holder = Instance.new("Part")
	holder.Name = "ChestLightBeam"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(base)
	local bottom = Instance.new("Attachment")
	bottom.Parent = holder
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.5, 0)
	top.Parent = holder

	local beam = Instance.new("Beam")
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.FaceCamera = true
	beam.Segments = 1
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 4
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	beam.Width0 = 0.55
	beam.Width1 = 0.2
	beam.Parent = holder
	holder.Parent = Workspace

	tweenNumber(0, 1, BEAM_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
		if not holder.Parent then
			return
		end
		top.Position = Vector3.new(0, 0.5 + BEAM_HEIGHT * math.min(alpha * 3, 1), 0) -- shoots up fast
		local fade = math.clamp((alpha - 0.45) / 0.55, 0, 1) -- then fades out
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05 + 0.95 * fade),
			NumberSequenceKeypoint.new(0.85, 0.35 + 0.65 * fade),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)
	Debris:AddItem(holder, BEAM_SECONDS + 0.2)
end

-- Scales the chest about its centre (ScaleTo scales about the pivot, at the chest's base).
local function squash(model)
	local base = model:GetPivot()
	local startScale = model:GetScale()
	local centreOffset = base:PointToObjectSpace(chestCentre(model))
	local function step(s)
		if model.Parent then
			s = math.max(s, 0.01)
			model:ScaleTo(startScale * s)
			model:PivotTo(base * CFrame.new(centreOffset * (1 - s)))
		end
	end
	tweenNumber(1, SQUASH_PEAK, SQUASH_GROW_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, step)
	task.delay(SQUASH_GROW_SECONDS, function()
		tweenNumber(SQUASH_PEAK, 0, SQUASH_SHRINK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, step)
	end)
end

-- A brief coloured flash around the edges of the screen (Secret opening, owner only): four
-- gradients fading in from the edges, in and out over `seconds`.
local function screenEdgeFlash(settings)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestScreenFlash"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	local edges = {
		{ UDim2.fromScale(1, SCREEN_EDGE), UDim2.fromScale(0, 0), 90 }, -- top: opaque at the edge
		{ UDim2.fromScale(1, SCREEN_EDGE), UDim2.fromScale(0, 1 - SCREEN_EDGE), -90 }, -- bottom
		{ UDim2.fromScale(SCREEN_EDGE, 1), UDim2.fromScale(0, 0), 0 }, -- left
		{ UDim2.fromScale(SCREEN_EDGE, 1), UDim2.fromScale(1 - SCREEN_EDGE, 0), 180 }, -- right
	}
	local frames = {}
	for _, edge in ipairs(edges) do
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = settings.Color
		frame.BackgroundTransparency = 1
		frame.Size = edge[1]
		frame.Position = edge[2]
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge[3]
		gradient.Transparency = NumberSequence.new(0, 1) -- solid at the screen edge, clear inward
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(frames, frame)
	end
	gui.Parent = playerGui
	local half = settings.Seconds / 2
	for _, frame in ipairs(frames) do
		local fadeIn = TweenService:Create(frame, TweenInfo.new(half * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = settings.Transparency })
		local fadeOut = TweenService:Create(frame, TweenInfo.new(settings.Seconds - half * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		fadeIn.Completed:Connect(function()
			fadeOut:Play()
		end)
		fadeIn:Play()
	end
	Debris:AddItem(gui, settings.Seconds + 0.1)
end

local function isMyChest(model)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	return prompt ~= nil and prompt:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
end

local function openChest(model)
	local entry = chests[model]
	if entry then
		entry.opened = true
	end
	setLoop(model, nil)

	local fx = ChestFxPresets.ForRarity(model:GetAttribute("Rarity"))
	local centre, base, tint = chestCentre(model), chestBase(model), rarityTint(model)
	local mine = isMyChest(model)
	local openSound = "Open_" .. tostring(model:GetAttribute("Rarity")) -- Open_Common .. Open_Secret
	AudioConfig.Play(AudioConfig.Sounds[openSound] and openSound or "Open_Common", centre)
	squash(model)
	task.delay(SQUASH_GROW_SECONDS, function() -- the burst comes out as the chest collapses
		VfxPlayer.PlayPreset(fx.Open, aimUp(centre), { tint = tint })
		if fx.OpenBeam then
			lightBeam(base)
		end
		if fx.ScreenFlash and mine then
			screenEdgeFlash(fx.ScreenFlash)
		end
	end)
end

-- The character that came out of a chest: it starts small at the chest's centre, arcs up and
-- lands on its slot (where the server put it), with a dust ring on landing.
popCharacter = function(model)
	local from, popAt = model:GetAttribute("PopFrom"), model:GetAttribute("PopAt")
	if typeof(from) ~= "Vector3" or typeof(popAt) ~= "number"
		or Workspace:GetServerTimeNow() - popAt > CHARACTER_POP_WINDOW
	then
		return
	end
	local target = model:GetPivot()
	local scale = model:GetScale()
	local boxCFrame, boxSize = model:GetBoundingBox()
	local centreOffset = boxCFrame.Position - target.Position -- world space, at full size
	local landing = boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0)
	local startPivot = from - centreOffset * CHARACTER_POP_START_SCALE -- puts its centre on the chest's
	tweenNumber(0, 1, CHARACTER_POP_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, function(t)
		if not model.Parent then
			return
		end
		local grow = 1 - (1 - math.min(t * 1.6, 1)) ^ 2 -- reaches full size a bit before landing
		model:ScaleTo(scale * (CHARACTER_POP_START_SCALE + (1 - CHARACTER_POP_START_SCALE) * grow))
		local position = startPivot:Lerp(target.Position, t) + Vector3.new(0, CHARACTER_POP_HEIGHT * 4 * t * (1 - t), 0)
		model:PivotTo(target.Rotation + position)
	end)
	task.delay(CHARACTER_POP_SECONDS, function()
		if model.Parent then
			model:ScaleTo(scale)
			model:PivotTo(target)
			VfxPlayer.PlayPreset(ChestFxPresets.ChestLand, aimUp(landing))
			AudioConfig.Play("CharacterAppear", landing)
			task.delay(AudioConfig.CoinDelaySeconds, function()
				AudioConfig.Play("CashTick", landing) -- the coin: a new earner on your plot
			end)
		end
	end)
end

treasureFx.OnClientEvent:Connect(function(kind, model)
	if kind == "ChestOpen" and typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
		openChest(model)
	end
end)
