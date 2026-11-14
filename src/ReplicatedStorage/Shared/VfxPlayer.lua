-- VfxPlayer (client only): plays particle VFX templates from ReplicatedStorage/VFX.
-- Visual only. Never decides gameplay; the server has already decided hits, rarity and spawns.
-- On a running server it warns and does nothing (effects made there would replicate to everyone);
-- in Studio edit mode it works, so effects can be previewed from the command bar.
--
-- Templates are the KitsBlox packs (PBlue, FistShotVFX_2, Frost, SplashPuddle): a transparent holder
-- Part with ParticleEmitters on it or on Attachments under it. Emitters can carry the attributes that
-- VFX Studio / Effect Designer Suite use, so effects tuned there play the same way here:
--   EmitCount (number)     how many particles to Emit() (0 = this layer never emits)
--   EmitDelay (number)     seconds to wait before emitting
--   EmitDuration (number)  if > 0, the emitter is switched on for this long instead of one Emit()
--
-- Layer options (Burst, Loop and preset layers):
--   scale        size multiplier: particle Size/Speed/Acceleration/ZOffset, the holder part and attachment offsets
--   countMul     particle count multiplier (bursts)
--   rateMul      Rate multiplier (loops)
--   only         emitter names to keep (nil = all); unknown names warn once
--   delay        seconds after the trigger (bursts)
--   ignoreDelay  ignore the packs' EmitDelay attributes; delayMul scales them instead
--   tint         recolours coloured layers, keeping their light/dark gradient (white cores stay white);
--   forceTint    = true tints white layers too
--   rotation     Vector3 (degrees) applied after `where` - aims the layer; packs fire toward their own
--                Front/Back/Top/Left face, so each pack needs its own aim
--   offset       Vector3 (studs) in the `where` frame (presets: the caller's and the layer's offsets add up)
--   anchor       "part" (preset layers): ignore the caller's offset and place the layer from the part
--                itself - for a chest's PrimaryPart that is its base
--   props        { Property = value } overrides for every kept emitter, applied after scaling
--   size         Vector3 holder-part size (loops: Shape-based emission around a chest)
--
-- Usage (presets live in ChestFxPresets):
--   VfxPlayer.PlayPreset(ChestFxPresets.ChestBurstBase, CFrame.lookAt(pos, pos + Vector3.yAxis, Vector3.zAxis))
--   local stop = VfxPlayer.LoopPreset(ChestFxPresets.IdleSparkle, chest.PrimaryPart, { tint = Color3.new(...) })
--   stop()
--   VfxPlayer.Burst("PBlue", cframe, { scale = 0.12, only = { "Impact550" }, rotation = Vector3.new(-90, 0, 0) })
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")

local VfxPlayer = {}

-- Phones and tablets (touch, no keyboard) get half the particles: the higher rarities stack a lot of layers.
VfxPlayer.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local MAX_PER_EMITTER = VfxPlayer.IsMobile and 20 or 40 -- caps packs with huge EmitCounts (Frost "Debree" is 512)
local MAX_LOOP_RATE = VfxPlayer.IsMobile and 20 or 40 -- particles per second per looping emitter
local MOBILE_COUNT_MUL = 0.5 -- burst counts on mobile
local MAX_DISTANCE = 300 -- bursts further than this from the camera are skipped
local DEFAULT_EMIT_COUNT = 8

local warned = {}

local function warnOnce(key, message)
	if not warned[key] then
		warned[key] = true
		warn("[VfxPlayer] " .. message)
	end
end

local function onServer()
	if RunService:IsServer() and RunService:IsRunning() then
		warnOnce("server", "VfxPlayer is client-only: call it from a LocalScript")
		return true
	end
	return false
end

local vfxFolder
local waitedForFolder = false

local function getFolder()
	if not (vfxFolder and vfxFolder.Parent) then
		vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		if not vfxFolder and not waitedForFolder then
			waitedForFolder = true -- wait once (it may still be replicating), never again
			vfxFolder = ReplicatedStorage:WaitForChild("VFX", 10)
		end
	end
	return vfxFolder
end

local function getRuntimeFolder()
	local folder = Workspace:FindFirstChild("VfxRuntime")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "VfxRuntime"
		folder.Parent = Workspace
	end
	return folder
end

local function scaleNumberSequence(seq, factor)
	local points = {}
	for _, kp in seq.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(kp.Time, kp.Value * factor, kp.Envelope * factor))
	end
	return NumberSequence.new(points)
end

local function luminance(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function isNearWhite(color)
	return color.R > 0.78 and color.G > 0.78 and color.B > 0.78
end

-- Keeps white cores white (they read as "light"), recolours coloured layers to the tint while
-- keeping each keypoint's relative brightness, so gradients still fade light -> dark.
local function applyTint(emitter, tint, force)
	local keypoints = emitter.Color.Keypoints
	if not force and isNearWhite(keypoints[1].Value) then
		return
	end
	local brightest = 0
	for _, kp in keypoints do
		brightest = math.max(brightest, luminance(kp.Value))
	end
	local points = {}
	for _, kp in keypoints do
		local k = brightest > 0 and math.clamp(luminance(kp.Value) / brightest, 0, 1) or 1
		table.insert(points, ColorSequenceKeypoint.new(kp.Time, Color3.new(tint.R * k, tint.G * k, tint.B * k)))
	end
	emitter.Color = ColorSequence.new(points)
end

local function nameAllowed(name, only)
	if not only then
		return true
	end
	for _, allowed in only do
		if allowed == name then
			return true
		end
	end
	return false
end

local function applyProps(emitter, props, templateName)
	for key, value in props do
		local ok, err = pcall(function()
			emitter[key] = value
		end)
		if not ok then
			warnOnce(templateName .. "." .. key, ("%s: can't set %s (%s)"):format(templateName, key, tostring(err)))
		end
	end
end

local function rotated(cframe, opts)
	if opts.offset then
		cframe = cframe * CFrame.new(opts.offset)
	end
	local r = opts.rotation
	if r then
		cframe = cframe * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end
	return cframe
end

-- Clones a template, removes emitters not in `only`, applies scale/tint/props.
-- Returns the holder part and the kept emitters.
local function prepare(templateName, opts)
	local folder = getFolder()
	local template = folder and folder:FindFirstChild(templateName)
	if not template then
		warnOnce(templateName, ("Missing ReplicatedStorage/VFX/%s"):format(templateName))
		return nil, {}
	end

	local clone = template:Clone()
	local scale = opts.scale or 1
	local emitters = {}
	local found = {}

	for _, inst in clone:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			inst:Destroy() -- effects must never run code
		elseif inst:IsA("ParticleEmitter") then
			if nameAllowed(inst.Name, opts.only) then
				found[inst.Name] = true
				inst.Enabled = false
				if scale ~= 1 then
					inst.Size = scaleNumberSequence(inst.Size, scale)
					inst.Speed = NumberRange.new(inst.Speed.Min * scale, inst.Speed.Max * scale)
					inst.Acceleration = inst.Acceleration * scale
					inst.ZOffset = inst.ZOffset * scale -- studs, like the rest
				end
				if opts.tint then
					applyTint(inst, opts.tint, opts.forceTint)
				end
				if opts.props then
					applyProps(inst, opts.props, templateName)
				end
				table.insert(emitters, inst)
			else
				inst:Destroy()
			end
		elseif inst:IsA("Attachment") then
			inst.Position = inst.Position * scale -- offsets shrink with the effect
		end
	end

	if opts.only then
		for _, name in opts.only do
			if not found[name] then
				warnOnce(templateName .. "/" .. name, ("%s has no emitter named %q"):format(templateName, name))
			end
		end
	end

	-- Every part in a template is only a holder: invisible, anchored, no physics.
	local holder = clone
	if not clone:IsA("BasePart") then
		holder = Instance.new("Part")
		holder.Name = templateName
		holder.Size = Vector3.one
		clone.Parent = holder
	end
	local parts = { holder }
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.Transparency = 1
	end
	holder.Size = opts.size or holder.Size * scale

	return holder, emitters
end

local function emitterLife(e)
	return e.Lifetime.Max / math.max(e.TimeScale, 0.01)
end

-- One-shot burst at a world CFrame (or Vector3). Returns the holder part (removed automatically).
function VfxPlayer.Burst(templateName, where, opts)
	opts = opts or {}
	if onServer() then
		return nil
	end
	local cframe = typeof(where) == "Vector3" and CFrame.new(where) or where
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - cframe.Position).Magnitude > MAX_DISTANCE then
		return nil -- too far away to see
	end
	local holder, emitters = prepare(templateName, opts)
	if not holder then
		return nil
	end

	holder.CFrame = rotated(cframe, opts)
	holder.Parent = getRuntimeFolder()

	local countMul = (opts.countMul or 1) * (VfxPlayer.IsMobile and MOBILE_COUNT_MUL or 1)
	local delayMul = opts.ignoreDelay and 0 or (opts.delayMul or 1)
	local startDelay = opts.delay or 0
	local longest = 0

	for _, e in emitters do
		local baseCount = e:GetAttribute("EmitCount") or DEFAULT_EMIT_COUNT
		local count = 0
		if baseCount > 0 and countMul > 0 then
			count = math.clamp(math.floor(baseCount * countMul + 0.5), 1, MAX_PER_EMITTER)
		end
		local delay = startDelay + (e:GetAttribute("EmitDelay") or 0) * delayMul
		local duration = e:GetAttribute("EmitDuration") or 0

		if duration > 0 then
			task.delay(delay, function()
				if e.Parent then
					e.Enabled = true
					task.delay(duration, function()
						if e.Parent then
							e.Enabled = false
						end
					end)
				end
			end)
		elseif count > 0 then
			if delay > 0 then
				task.delay(delay, function()
					if e.Parent then
						e:Emit(count)
					end
				end)
			else
				e:Emit(count)
			end
		end
		longest = math.max(longest, delay + duration + emitterLife(e))
	end

	Debris:AddItem(holder, longest + 0.5)
	return holder
end

-- Looping effect that follows a part (e.g. idle sparkle on a chest). Returns a stop() function.
-- The template's holder part is kept (so Shape-based emission and attachment offsets still work),
-- welded to `parentPart`, and cleaned up when stop() is called or the part is removed.
function VfxPlayer.Loop(templateName, parentPart, opts)
	opts = opts or {}
	if onServer() then
		return function() end
	end
	if not (parentPart and parentPart:IsA("BasePart")) then
		warnOnce("loopParent", ("Loop %s needs a BasePart to follow, got %s"):format(templateName, tostring(parentPart)))
		return function() end
	end
	local holder, emitters = prepare(templateName, opts)
	if not holder then
		return function() end
	end

	holder.CFrame = rotated(parentPart.CFrame, opts)
	holder.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parentPart
	weld.Part1 = holder
	weld.Parent = holder
	holder.Parent = getRuntimeFolder()

	local rateMul = opts.rateMul or 1
	for _, e in emitters do
		if e.Rate <= 0 then
			warnOnce(templateName .. "/" .. e.Name .. "/rate", ("%s/%s has Rate 0, so it shows nothing in a loop"):format(templateName, e.Name))
		end
		e.Rate = math.min(e.Rate * rateMul, MAX_LOOP_RATE)
		e.Enabled = true
	end

	local stopped = false
	local connection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if connection then
			connection:Disconnect()
		end
		-- Unweld before anchoring: an anchored holder still welded to the part would anchor it too.
		weld:Destroy()
		holder.Anchored = true -- stay put while the last particles fade
		local longest = 0
		for _, e in emitters do
			if e.Parent then
				e.Enabled = false
			end
			longest = math.max(longest, emitterLife(e))
		end
		Debris:AddItem(holder, longest + 0.2)
	end
	connection = parentPart.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stop()
		end
	end)
	return stop
end

-- A preset layer's options plus the caller's extraOpts: extraOpts fill in options the layer doesn't
-- set itself (e.g. tint = RarityTint[rarity]); offsets add up (the caller's offset places the whole
-- preset, a layer's offset is relative to that), except for layers with anchor = "part", which
-- are placed from the part itself (for a chest: its base) and ignore the caller's offset.
local function layerOptions(layer, extraOpts)
	local opts = table.clone(layer)
	for k, v in extraOpts do
		if k == "offset" and layer.anchor == "part" then
			continue
		elseif k == "offset" and opts.offset then
			opts.offset = v + opts.offset
		elseif opts[k] == nil then
			opts[k] = v
		end
	end
	return opts
end

-- Runs one layer; a broken layer warns once instead of stopping the rest of the preset.
local function safely(what, fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		warnOnce(what .. ":" .. tostring(result), ("%s failed: %s"):format(what, tostring(result)))
		return nil
	end
	return result
end

-- Plays a preset (a list of layers) from ChestFxPresets at a world CFrame. Returns the holder
-- parts it made (e.g. to slow their emitters down for a moment).
function VfxPlayer.PlayPreset(preset, where, extraOpts)
	extraOpts = extraOpts or {}
	local holders = {}
	for _, layer in preset do
		local holder = safely("Burst " .. tostring(layer.template), VfxPlayer.Burst, layer.template, where, layerOptions(layer, extraOpts))
		if holder then
			table.insert(holders, holder)
		end
	end
	return holders
end

-- Starts a looping preset: either one layer ({ template = ... }) or a list of layers.
-- Returns one stop() for all of them.
function VfxPlayer.LoopPreset(preset, parentPart, extraOpts)
	extraOpts = extraOpts or {}
	local layers = preset.template and { preset } or preset
	local stops = {}
	for _, layer in layers do
		local stop = safely("Loop " .. tostring(layer.template), VfxPlayer.Loop, layer.template, parentPart, layerOptions(layer, extraOpts))
		if stop then
			table.insert(stops, stop)
		end
	end
	return function()
		for _, stop in stops do
			stop()
		end
	end
end

-- Loads every pack texture up front, so the first burst a player sees isn't missing layers.
-- Runs by itself on clients; yields while loading.
function VfxPlayer.Preload()
	local folder = getFolder()
	if not folder then
		return
	end
	local ids, seen = {}, {}
	for _, inst in folder:GetDescendants() do
		if inst:IsA("ParticleEmitter") and inst.Texture ~= "" and not seen[inst.Texture] then
			seen[inst.Texture] = true
			table.insert(ids, inst.Texture)
		end
	end
	ContentProvider:PreloadAsync(ids)
end

if RunService:IsClient() and RunService:IsRunning() then
	task.spawn(VfxPlayer.Preload)
end

return VfxPlayer
