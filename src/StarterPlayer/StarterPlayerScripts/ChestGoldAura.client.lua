-- ChestGoldAura: the warm gold glow every chest sits in (client, visual only).
-- Chests tagged TreasureModels.GOLD_AURA_TAG get, tuned in ChestFxPresets.GoldAura / GoldShimmer:
--   * a soft golden halo behind the chest (BillboardGui, not always on top, pushed away from
--     the camera so the chest stays in front of it), pulsing in size and transparency
--   * one warm gold PointLight pulsing with the halo
--   * slow golden sparkles drifting up (a VfxPlayer loop)
--   * a quick gold Highlight flash every few seconds
-- The server tags carried and plot chests (Carry.MakeTreasure); DigClient tags the chest when
-- it emerges. The aura stops when the chest starts opening (Opening attribute) or is removed,
-- and switches off while the chest is further than CullDistance from the camera.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local VfxPlayer = require(Shared:WaitForChild("VfxPlayer"))
local ChestFxPresets = require(Shared:WaitForChild("ChestFxPresets"))

local Aura = ChestFxPresets.GoldAura
local Shimmer = ChestFxPresets.GoldShimmer
local TAG = TreasureModels.GOLD_AURA_TAG
local CULL_CHECK_SECONDS = 0.25
local ROOT_WAIT_SECONDS = 5 -- a streamed-in chest may arrive before its PrimaryPart

local auras = {} -- [chest Model] = aura

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function nextShimmerAt(now)
	return now + lerp(Shimmer.Interval.Min, Shimmer.Interval.Max, math.random())
end

local function startSparkles(aura)
	if not aura.StopSparkles then
		aura.StopSparkles = VfxPlayer.LoopPreset(Aura.Sparkles, aura.Root, { offset = aura.Centre })
	end
end

local function stopSparkles(aura)
	if aura.StopSparkles then
		aura.StopSparkles()
		aura.StopSparkles = nil
	end
end

-- Near the camera: everything on. Far away: halo, light and sparkles off.
local function setNear(aura, near)
	aura.Near = near
	aura.Halo.Enabled = near
	aura.Light.Enabled = near
	if near then
		startSparkles(aura)
	else
		stopSparkles(aura)
	end
end

-- A quick gold flash over the whole chest: fades in, then out. The Highlight only exists
-- during the flash (clients can show a limited number at once).
local function shimmer(aura)
	local highlight = Instance.new("Highlight")
	highlight.Adornee = aura.Model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Shimmer.Color
	highlight.OutlineColor = Shimmer.OutlineColor
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = aura.Attachment
	local half = Shimmer.Seconds / 2
	local flashIn = TweenService:Create(highlight, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = Shimmer.FillTransparency,
		OutlineTransparency = Shimmer.OutlineTransparency,
	})
	local flashOut = TweenService:Create(highlight, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})
	flashIn.Completed:Connect(function()
		flashOut:Play()
	end)
	flashOut.Completed:Connect(function()
		highlight:Destroy()
	end)
	flashIn:Play()
end

local function detach(model)
	local aura = auras[model]
	if not aura then
		return
	end
	auras[model] = nil
	stopSparkles(aura)
	for _, connection in ipairs(aura.Connections) do
		connection:Disconnect()
	end
	aura.Attachment:Destroy() -- takes the halo, light and any shimmer with it
end

local function attach(model)
	if auras[model] or not model:IsA("Model") or not model:IsDescendantOf(Workspace) or model:GetAttribute("Opening") then
		return
	end
	local root = model.PrimaryPart
	local deadline = os.clock() + ROOT_WAIT_SECONDS
	while not root and os.clock() < deadline and model.Parent do
		task.wait(0.1)
		root = model.PrimaryPart
	end
	if not root or auras[model] or not model:IsDescendantOf(Workspace) or not CollectionService:HasTag(model, TAG) then
		return
	end

	local boxCFrame, boxSize = model:GetBoundingBox()
	local chestSize = math.max(boxSize.X, boxSize.Y, boxSize.Z)
	-- a little above the chest's centre, so the ground doesn't cut off much of the halo
	local centre = root.CFrame:PointToObjectSpace(boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.15, 0))

	local attachment = Instance.new("Attachment")
	attachment.Name = "GoldAura"
	attachment.Position = centre
	attachment.Parent = root

	local halo = Instance.new("BillboardGui")
	halo.Name = "GoldHalo"
	halo.AlwaysOnTop = false
	halo.LightInfluence = 0
	halo.Brightness = Aura.HaloBrightness
	halo.MaxDistance = Aura.CullDistance
	-- StudsOffset is in camera space, where -Z points away from the camera: behind the chest
	halo.StudsOffset = Vector3.new(0, 0, -chestSize * Aura.HaloBehind)
	halo.Parent = attachment
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = Aura.HaloImage
	image.ImageColor3 = Aura.Color
	image.Parent = halo

	local light = Instance.new("PointLight")
	light.Color = Aura.Color
	light.Range = Aura.LightRange
	light.Parent = attachment

	local aura = {
		Model = model,
		Root = root,
		Centre = centre,
		Attachment = attachment,
		Halo = halo,
		Image = image,
		Light = light,
		HaloSize = chestSize * Aura.HaloScale,
		Phase = math.random() * math.pi * 2, -- chests side by side don't pulse in step
		NextShimmer = nextShimmerAt(os.clock()),
		Near = true,
		Connections = {},
	}
	auras[model] = aura
	startSparkles(aura)
	table.insert(aura.Connections, model:GetAttributeChangedSignal("Opening"):Connect(function()
		if model:GetAttribute("Opening") then
			detach(model) -- ChestOpen takes over
		end
	end))
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(attach, model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
	task.spawn(attach, model)
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach) -- untagged, destroyed or streamed out

-- Pulse (halo size and transparency, light brightness), shimmer timing and distance culling.
local nextCullCheck = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local checkDistance = camera and now >= nextCullCheck
	if checkDistance then
		nextCullCheck = now + CULL_CHECK_SECONDS
	end
	for _, aura in pairs(auras) do
		if checkDistance then
			local near = (aura.Attachment.WorldPosition - camera.CFrame.Position).Magnitude <= Aura.CullDistance
			if near ~= aura.Near then
				setNear(aura, near)
			end
		end
		if aura.Near then
			local wave = (math.sin(now * math.pi * 2 / Aura.PulseSeconds + aura.Phase) + 1) / 2 -- 0 low .. 1 peak
			local size = aura.HaloSize * (1 + Aura.PulseSize * (wave * 2 - 1))
			aura.Halo.Size = UDim2.fromScale(size, size) -- BillboardGui scale is in studs
			aura.Image.ImageTransparency = lerp(Aura.HaloTransparency.Low, Aura.HaloTransparency.Peak, wave)
			aura.Light.Brightness = lerp(Aura.LightBrightness.Low, Aura.LightBrightness.Peak, wave)
			if now >= aura.NextShimmer then
				aura.NextShimmer = nextShimmerAt(now)
				shimmer(aura)
			end
		end
	end
end)
