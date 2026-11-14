-- ChestAura (client only): the rarity aura on one chest, built from ChestFxPresets.RarityFx.
-- StarterPlayerScripts/ChestAura decides which chests get one and what is switched on (distance,
-- limits, carried or not); this module builds and animates the pieces:
--   * Halo: a soft glow behind the chest (BillboardGui, not always on top, pushed away from the
--     camera), pulsing in size and transparency, with an optional random flicker (Secret)
--   * Gem light: the chest's one PointLight, on its Gem (or its centre), pulsing with the halo
--   * Sparkles: an optional VfxPlayer loop around the chest (Legendary gold, Secret dark red)
--   * Sky beam: an optional Beam from the top of the chest straight up, gently pulsing, with a
--     quiet BeamHum loop at its foot while it is on
--   * Shimmer: a quick Highlight flash in the glow colour
-- Works in Studio edit mode too, so a chest can be previewed from the command bar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VfxPlayer = require(Shared:WaitForChild("VfxPlayer"))
local ChestFxPresets = require(Shared:WaitForChild("ChestFxPresets"))
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))

local AuraConfig = ChestFxPresets.ChestAura
local Shimmer = ChestFxPresets.ChestShimmer

local ChestAura = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Builds the aura for a chest (it must have a PrimaryPart; its Rarity attribute picks the look).
-- Everything starts switched off; use SetHalo / SetLight / SetSparkles / SetBeam.
function ChestAura.Build(model)
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local rarity = model:GetAttribute("Rarity")
	local fx = ChestFxPresets.ForRarity(rarity)
	local glow = fx.Glow
	local boxCFrame, boxSize = model:GetBoundingBox()
	local chestSize = math.max(boxSize.X, boxSize.Y, boxSize.Z)
	-- a little above the chest's centre, so the ground doesn't cut off much of the halo
	local centre = root.CFrame:PointToObjectSpace(boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.15, 0))

	local attachment = Instance.new("Attachment")
	attachment.Name = "ChestAura"
	attachment.Position = centre
	attachment.Parent = root

	local halo = Instance.new("BillboardGui")
	halo.Name = "Halo"
	halo.Enabled = false
	halo.AlwaysOnTop = false
	halo.LightInfluence = 0
	halo.Brightness = glow.HaloBrightness
	-- StudsOffset is in camera space, where -Z points away from the camera: behind the chest
	halo.StudsOffset = Vector3.new(0, 0, -chestSize * AuraConfig.HaloBehind)
	halo.Parent = attachment
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = AuraConfig.HaloImage
	image.ImageColor3 = glow.Color
	image.Parent = halo

	-- The one light: on the Gem when there is one (the gem glows), else the chest's centre.
	local gem = model:FindFirstChild("Gem", true)
	local light = Instance.new("PointLight")
	light.Name = "ChestAuraLight"
	light.Enabled = false
	light.Color = ChestFxPresets.RarityTint[rarity] or glow.Color
	light.Range = fx.GemLight.Range
	light.Parent = (gem and gem:IsA("BasePart")) and gem or attachment

	local beam
	if fx.SkyBeam then
		local top = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0)
		local bottom = Instance.new("Attachment")
		bottom.Name = "SkyBeamBottom"
		bottom.Position = root.CFrame:PointToObjectSpace(top)
		bottom.Parent = root
		local up = Instance.new("Attachment")
		up.Name = "SkyBeamTop"
		up.Position = root.CFrame:PointToObjectSpace(top + Vector3.new(0, fx.SkyBeam.Height, 0))
		up.Parent = root
		beam = Instance.new("Beam")
		beam.Name = "SkyBeam"
		beam.Enabled = false
		beam.Attachment0 = bottom
		beam.Attachment1 = up
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightEmission = fx.SkyBeam.LightEmission or 0
		beam.LightInfluence = 0
		beam.Brightness = fx.SkyBeam.Brightness
		beam.Color = ColorSequence.new(glow.Color)
		beam.Width0 = fx.SkyBeam.Width0
		beam.Width1 = fx.SkyBeam.Width1
		beam.Parent = root
	end

	return {
		Model = model,
		Root = root,
		Fx = fx,
		Centre = centre,
		Attachment = attachment,
		Halo = halo,
		Image = image,
		Light = light,
		Beam = beam,
		HaloSize = chestSize * glow.HaloScale,
		Phase = math.random() * math.pi * 2, -- chests side by side don't pulse in step
		StopSparkles = nil,
	}
end

function ChestAura.SetHalo(aura, on)
	aura.Halo.Enabled = on
end

function ChestAura.SetLight(aura, on)
	aura.Light.Enabled = on
end

function ChestAura.SetBeam(aura, on)
	if not aura.Beam then
		return
	end
	aura.Beam.Enabled = on
	if on and not aura.BeamHum then
		aura.BeamHum = AudioConfig.Play("BeamHum", aura.Beam.Attachment0, { Looped = true })
	elseif not on and aura.BeamHum then
		aura.BeamHum:Destroy()
		aura.BeamHum = nil
	end
end

-- rateMul scales the sparkle rate (lower on mobile).
function ChestAura.SetSparkles(aura, on, rateMul)
	local layers = aura.Fx.Glow.Sparkles
	if on and layers and not aura.StopSparkles then
		if rateMul and rateMul ~= 1 then
			local scaled = {}
			for i, layer in ipairs(layers) do
				scaled[i] = table.clone(layer)
				scaled[i].rateMul = (layer.rateMul or 1) * rateMul
			end
			layers = scaled
		end
		aura.StopSparkles = VfxPlayer.LoopPreset(layers, aura.Root, { offset = aura.Centre })
	elseif not on and aura.StopSparkles then
		aura.StopSparkles()
		aura.StopSparkles = nil
	end
end

function ChestAura.HasSparkles(aura)
	return aura.Fx.Glow.Sparkles ~= nil
end

-- Animates the pulse (and flicker) at time `now` (os.clock()).
function ChestAura.Update(aura, now)
	local fx = aura.Fx
	local glow = fx.Glow
	local wave = (math.sin(now * math.pi * 2 / glow.PulseSeconds + aura.Phase) + 1) / 2 -- 0 low .. 1 peak
	if glow.Flicker and glow.Flicker > 0 then
		wave = math.clamp(wave + glow.Flicker * 2 * math.noise(now * 14, aura.Phase * 7), 0, 1)
	end
	if aura.Halo.Enabled then
		local size = aura.HaloSize * (1 + glow.PulseSize * (wave * 2 - 1))
		aura.Halo.Size = UDim2.fromScale(size, size) -- BillboardGui scale is in studs
		aura.Image.ImageTransparency = lerp(glow.HaloTransparency.Low, glow.HaloTransparency.Peak, wave)
	end
	if aura.Light.Enabled then
		aura.Light.Brightness = lerp(fx.GemLight.Brightness.Low, fx.GemLight.Brightness.Peak, wave)
	end
	if aura.Beam and aura.Beam.Enabled then
		local sky = fx.SkyBeam
		local beamWave = (math.sin(now * math.pi * 2 / sky.PulseSeconds + aura.Phase) + 1) / 2
		local t = lerp(sky.Transparency.Low, sky.Transparency.Peak, beamWave)
		aura.Beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, t),
			NumberSequenceKeypoint.new(0.75, t + (1 - t) * 0.35),
			NumberSequenceKeypoint.new(1, 1), -- fades out at the top
		})
	end
end

-- A quick flash over the whole chest in its glow colour: fades in, then out. The Highlight only
-- exists during the flash (clients can show a limited number at once).
function ChestAura.Shimmer(aura)
	local color = aura.Fx.Glow.Color
	local highlight = Instance.new("Highlight")
	highlight.Adornee = aura.Model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.5)
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

function ChestAura.Destroy(aura)
	ChestAura.SetSparkles(aura, false)
	aura.Attachment:Destroy() -- takes the halo and any shimmer with it
	aura.Light:Destroy()
	if aura.Beam then
		aura.Beam.Attachment0:Destroy()
		aura.Beam.Attachment1:Destroy()
		aura.Beam:Destroy()
	end
end

return ChestAura
