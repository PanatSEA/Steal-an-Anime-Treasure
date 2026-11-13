-- ChestFx: chest VFX on plots (client, visual only; the server decides everything).
--   * ChestLand when a chest lands on a plot (the server stamps new chests with PlacedAt, so
--     chests that were already there when you joined, or that stream back in, don't replay it).
--   * IdleSparkle loop while a chest's unlock timer runs, ReadyToOpen loop once it can be opened.
--     Loops stop when the chest is opened or removed.
--   * ChestOpen (tinted by RarityTint[rarity]) plus a thin white light beam when the server opens a
--     chest; chests with a "Lid" model also swing the lid open.
--   * Rainbow colour cycle for Secret glows.
-- Effects come from ReplicatedStorage/VFX via VfxPlayer; tune them in ChestFxPresets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local VfxPlayer = require(Shared:WaitForChild("VfxPlayer"))
local ChestFxPresets = require(Shared:WaitForChild("ChestFxPresets"))

local treasureFx = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("TreasureFx")

local LID_OPEN_DEGREES = 110
local LID_OPEN_SECONDS = 0.45
local RAINBOW_SPEED = 0.35 -- hue cycles per second
local BEAM_HEIGHT = 22
local BEAM_SECONDS = 1.3
local PROMPT_WAIT_SECONDS = 5
local LAND_WINDOW_SECONDS = 2 -- chests placed less than this long ago get the landing effect

local chests = {} -- [chest Model] = { state = "Idle" | "Ready" | nil, stop = fn?, opened = bool }

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

local function openLid(lid)
	local closed = lid:GetPivot()
	-- The lid's pivot sits on the back hinge; rotating about its X axis lifts the front.
	tweenNumber(0, 1, LID_OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
		if lid.Parent then
			lid:PivotTo(closed * CFrame.Angles(math.rad(LID_OPEN_DEGREES * alpha), 0, 0))
		end
	end)
end

local function fadeOut(model, delaySeconds)
	task.delay(delaySeconds, function()
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
	end)
end

local function openChest(model)
	local entry = chests[model]
	if entry then
		entry.opened = true
	end
	setLoop(model, nil)

	local lid = TreasureModels.GetLid(model)
	if lid then
		openLid(lid)
	end
	VfxPlayer.PlayPreset(ChestFxPresets.ChestOpen, aimUp(chestCentre(model)), { tint = rarityTint(model) })
	lightBeam(chestBase(model))
	if not lid then
		fadeOut(model, 0.15) -- single-mesh chests burst open: the chest fades into the flash
	end
end

treasureFx.OnClientEvent:Connect(function(kind, model)
	if kind == "ChestOpen" and typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
		openChest(model)
	end
end)

-- Secret glows (light, aura, glow sprite) cycle through the rainbow on every client.
RunService.RenderStepped:Connect(function()
	local color = Color3.fromHSV((os.clock() * RAINBOW_SPEED) % 1, 0.85, 1)
	for _, piece in ipairs(CollectionService:GetTagged(TreasureModels.RAINBOW_TAG)) do
		if piece:IsA("BasePart") or piece:IsA("Light") then
			piece.Color = color
		elseif piece:IsA("ParticleEmitter") then
			piece.Color = ColorSequence.new(color)
		end
	end
end)
