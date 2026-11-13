-- ChestFx: the chest-opening animation on plots, plus the rainbow cycle for Secret glows.
-- Visual only; the server has already decided the character.
--   * Chest with a "Lid" model (hinge at the back): the lid swings open and coins pop out.
--   * Single-mesh chest (no lid): a burst instead - white flash, rarity light beam,
--     sparkles and coins - while the chest fades into the flash. No lid motion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local TreasureModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreasureModels"))

local treasureFx = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("TreasureFx")

local LID_OPEN_DEGREES = 110
local LID_OPEN_SECONDS = 0.45
local COIN_COUNT = 12
local COIN_COLOR = Color3.fromRGB(255, 205, 60)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local BURST_BEAM_HEIGHT = 16
local RAINBOW_SPEED = 0.35 -- hue cycles per second

local function tweenNumber(from, to, seconds, style, direction, onStep)
	local value = Instance.new("NumberValue")
	value.Value = from
	local connection = value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = to })
	tween.Completed:Connect(function()
		connection:Disconnect()
		value:Destroy()
	end)
	tween:Play()
end

local function effectPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = Workspace
	return p
end

local function chestCentre(model)
	local boxCFrame = model:GetBoundingBox()
	return boxCFrame.Position
end

local function chestTop(model)
	local pivot = model:GetPivot()
	local top = TreasureModels.Height(model) - TreasureModels.PivotHeight(model)
	return (pivot * CFrame.new(0, top, 0)).Position
end

local function popCoins(origin)
	for _ = 1, COIN_COUNT do
		local coin = effectPart({
			Name = "Coin",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 0.8, 0.8),
			Color = COIN_COLOR,
			Material = Enum.Material.Metal,
			Anchored = false,
			CFrame = CFrame.new(origin) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
		})
		coin.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(22, 32), math.random(-8, 8))
		coin.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		task.delay(0.7, function()
			if coin.Parent then
				TweenService:Create(coin, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(coin, 1.2)
	end
end

local function openLid(model, lid)
	local closed = lid:GetPivot()
	-- The lid's pivot sits on the back hinge; rotating about its X axis lifts the front.
	tweenNumber(0, 1, LID_OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
		if lid.Parent then
			lid:PivotTo(closed * CFrame.Angles(math.rad(LID_OPEN_DEGREES * alpha), 0, 0))
		end
	end)
	task.delay(0.2, popCoins, chestTop(model) + Vector3.new(0, 0.3, 0))
end

local function burst(model)
	local rarity = model:GetAttribute("Rarity")
	local color = TreasureModels.GlowColor(rarity)
	local rainbow = TreasureModels.IsRainbow(rarity)
	local centre = chestCentre(model)
	local base = (model:GetPivot() * CFrame.new(0, -TreasureModels.PivotHeight(model), 0)).Position

	-- Flash: a white sphere that swells and fades.
	local flash = effectPart({ Name = "OpenFlash", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1),
		Color = Color3.new(1, 1, 1), Transparency = 0.1, CFrame = CFrame.new(centre) })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 6
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.7)

	-- Light beam in the rarity colour.
	local beam = effectPart({ Name = "OpenBeam", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(BURST_BEAM_HEIGHT, 2.2, 2.2), Color = color, Transparency = 1,
		CFrame = CFrame.new(base + Vector3.new(0, BURST_BEAM_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	if rainbow then
		CollectionService:AddTag(beam, TreasureModels.RAINBOW_TAG)
	end
	TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 0.35 }):Play()
	task.delay(0.35, function()
		if beam.Parent then
			TweenService:Create(beam, TweenInfo.new(0.8), { Transparency = 1, Size = Vector3.new(BURST_BEAM_HEIGHT, 0.2, 0.2) }):Play()
		end
	end)
	Debris:AddItem(beam, 1.3)

	-- Sparkle burst.
	local holder = effectPart({ Name = "OpenSparkles", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(centre) })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Enabled = false
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.LightEmission = 1
	sparkles.Color = rainbow and TreasureModels.RainbowSequence() or ColorSequence.new(color)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(10, 20)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Drag = 3
	sparkles.Parent = attachment
	sparkles:Emit(60)
	Debris:AddItem(holder, 1.5)

	popCoins(centre + Vector3.new(0, 0.5, 0))

	-- The chest fades into the flash (the server removes it shortly after).
	task.delay(0.1, function()
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
	end)
end

local function openChest(model)
	local lid = TreasureModels.GetLid(model)
	if lid then
		openLid(model, lid)
	else
		burst(model)
	end
end

treasureFx.OnClientEvent:Connect(function(kind, model)
	if kind == "ChestOpen" and typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
		openChest(model)
	end
end)

-- Secret glows (halo, light, aura, beams) cycle through the rainbow on every client.
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
