-- ChestFxPresets: which VFX layers play at each moment of the dig/chest sequence.
-- Tune here only. Emitter names come from the KitsBlox packs in ReplicatedStorage/VFX
-- (docs/00_Game_Plan/VFX_Plan.md lists what each emitter looks like).
--
-- Look (from the reference picture): a pink-white starburst and a big yellow star on each pickaxe
-- hit with tan rock chips and blue crystal splinters flying; on hit 3 the chest bursts out of the
-- rock. Everything about the chest itself scales with its rarity (RarityFx): its glow, gem light,
-- sky beam, the burst on hit 3 and the opening.
--
-- Bursts are played at a CFrame whose LookVector is the main direction (toward the digger for
-- hits, straight up for the chest). Each pack fires toward its own face, so `rotation` turns that
-- face onto the LookVector: FistShotVFX_2 fires Front (no rotation), Frost's shards fire Back,
-- Frost's Star fires Left, PBlue, SplashPuddle and the Shockwave rings fire Top. In an up-aimed burst, offset (0, 0, -n)
-- moves a layer n studs up. Loops follow the chest's own axes instead (Y = up, offset (0, n, 0)).
--
-- Things the packs need here: the sand is bright, so most layers keep their own (normal) blending
-- and get a strong tint; ZOffset pulls flashes in front of the rock and chest; Part-based packs
-- (FistShotVFX_2, Frost) emit from their whole holder box unless `size = POINT`.
--
-- Layer options (all in VfxPlayer): template, only, scale, countMul, rateMul, delay, ignoreDelay,
-- tint (Color3; false keeps the pack's colours; layers without one get RarityTint where the
-- caller passes it), forceTint (tint white layers too), rotation, offset, anchor, props, size.

local ChestFxPresets = {}

-- Rarity colours, matching the chests' trims. Used for every rarity-coloured effect and the gem.
ChestFxPresets.RarityTint = {
	Common = Color3.fromRGB(220, 225, 235), -- silver-white
	Epic = Color3.fromRGB(170, 100, 255), -- purple
	Legendary = Color3.fromRGB(255, 200, 60), -- gold
	Secret = Color3.fromRGB(255, 40, 40), -- red (not pink)
}
local TINT = ChestFxPresets.RarityTint

-- Burst aims: turn each pack's emission face onto the preset's LookVector.
local BACK = Vector3.new(0, 180, 0)
local LEFT = Vector3.new(0, -90, 0)
local TOP = Vector3.new(-90, 0, 0)
local POINT = Vector3.new(0.1, 0.1, 0.1)

local FLASH_PINK = Color3.fromRGB(255, 120, 200)
local STAR_YELLOW = Color3.fromRGB(255, 214, 50)
local RAY_ORANGE = Color3.fromRGB(255, 150, 20) -- rays stand out against the golden glow
local AURA_GOLD = Color3.fromRGB(255, 200, 80) -- the Legendary glow (warmer than the trim)
local DARK_RED = Color3.fromRGB(150, 10, 10)
local ROCK = Color3.fromRGB(176, 146, 104) -- a little darker than the mound so chips show on the sand
local DUST = Color3.fromRGB(252, 248, 238) -- cream-white cartoon puffs
local DUST_RING = Color3.fromRGB(196, 168, 124)
local WHITE = Color3.new(1, 1, 1)

local function life(min, max)
	return NumberRange.new(min, max or min)
end

-- NumberSequence from time/value pairs: seq(0, a, 0.5, b, 1, c)
local function seq(...)
	local args = { ... }
	local points = {}
	for i = 1, #args, 2 do
		table.insert(points, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(points)
end

-- One big Frost "Star" that pops and shrinks, without moving (sizes in studs).
local function bigStar(peak, seconds, zOffset)
	return {
		Speed = NumberRange.new(0, 0),
		Size = seq(0, peak / 3, 0.25, peak, 1, 0),
		Lifetime = life(seconds),
		Rotation = NumberRange.new(-10, 10),
		ZOffset = zOffset,
		Brightness = 1.5, -- the pack's 5.2 washes yellow and rarity colours out to white
	}
end

-- Layer builders shared by the rarity bursts and openings (up-aimed presets).
local function flash(scale, color, seconds, brightness)
	return { template = "FistShotVFX_2", only = { "GlowImpact" }, size = POINT, scale = scale, tint = color or false, forceTint = color ~= nil,
		props = { Lifetime = life(seconds), Brightness = brightness, ZOffset = 2 } }
end
local function glowRing(scale, color, up, seconds, delay)
	return { template = "PBlue", only = { "ring" }, offset = Vector3.new(0, 0, -up), rotation = TOP, scale = scale, ignoreDelay = true, delay = delay, tint = color, props = {
		Transparency = seq(0, 0.2, 0.45, 0.45, 1, 1),
		Lifetime = life(seconds),
		ZOffset = -1.5,
	} }
end
local function rays(scale, color, up, seconds)
	return { template = "PBlue", only = { "Impact550" }, offset = Vector3.new(0, 0, -up), rotation = TOP, scale = scale, ignoreDelay = true, tint = color,
		props = { Lifetime = life(seconds), Brightness = 1.4, ZOffset = -1 } }
end
local function starburst(scale, color, seconds)
	return { template = "PBlue", only = { "Impact356" }, rotation = TOP, scale = scale, ignoreDelay = true, tint = color,
		props = { Lifetime = life(seconds), Brightness = 1.5, ZOffset = 2.5 } }
end
local function sparks(scale, color, countMul)
	return { template = "PBlue", only = { "RedFire2" }, rotation = TOP, scale = scale, ignoreDelay = true, countMul = countMul, tint = color,
		props = { Brightness = 1.5, ZOffset = 1 } }
end
local function twinkles(color, countMul, speed)
	return { template = "Frost", only = { "Star" }, rotation = LEFT, size = POINT, countMul = countMul, tint = color, forceTint = true, props = {
		Speed = NumberRange.new(speed * 0.5, speed),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 3,
		Size = seq(0, 0, 0.2, 1.4, 1, 0),
		Lifetime = life(0.6, 0.9),
		ZOffset = 1,
	} }
end
local function groundRing(scale, color, delay)
	return { template = "FistShotVFX_2", only = { "Shockwave1" }, rotation = TOP, size = POINT, scale = scale, delay = delay, tint = color or false, forceTint = color ~= nil, props = {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.zero,
	} }
end
-- Square bits tumbling up and falling back (the pack's rock chips, made square-ish and slow).
local function confetti(color, countMul, size)
	return { template = "FistShotVFX_2", only = { "Shards" }, size = POINT, countMul = countMul, tint = color, forceTint = true, props = {
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Squash = seq(0, 0, 1, 0),
		Size = seq(0, size, 0.8, size, 1, 0),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 1.5,
		Acceleration = Vector3.new(0, -45, 0),
		Lifetime = life(0.9, 1.3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-260, 260),
		LightEmission = 0.2,
		Brightness = 1.2,
		ZOffset = 1,
	} }
end

-- Pickaxe hits 1 and 2: at the impact point, aimed toward the digger and up.
ChestFxPresets.DigHit = {
	-- pink-white starburst flash
	{ template = "PBlue", only = { "Impact356" }, rotation = TOP, scale = 0.09, ignoreDelay = true, tint = FLASH_PINK, props = { Lifetime = life(0.2), ZOffset = 3 } },
	{ template = "PBlue", only = { "Impact550" }, rotation = TOP, scale = 0.12, ignoreDelay = true, tint = FLASH_PINK, props = { Lifetime = life(0.28), ZOffset = 2.5 } },
	-- big yellow star
	{ template = "Frost", only = { "Star" }, size = POINT, countMul = 0.125, tint = STAR_YELLOW, props = bigStar(6.5, 0.24, 3.5) },
	-- small yellow stars, tan rock chips and blue crystal splinters flying out
	{ template = "FistShotVFX_2", only = { "Stars" }, size = POINT, scale = 0.22, countMul = 0.4, tint = STAR_YELLOW, forceTint = true, props = { Brightness = 1.5, ZOffset = 2 } },
	{ template = "FistShotVFX_2", only = { "Shards" }, size = POINT, scale = 0.4, countMul = 0.35, tint = ROCK, forceTint = true, props = { Acceleration = Vector3.new(0, -50, 0), ZOffset = 1 } },
	{ template = "Frost", only = { "BrightBlueSharpShard", "BrightBlueDiolveShard" }, rotation = BACK, size = POINT, scale = 0.28, tint = false, props = { SpreadAngle = Vector2.new(40, 40), ZOffset = 1 } },
	-- cartoon dust puffs
	{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.6, countMul = 0.35, tint = DUST, forceTint = true, props = { Speed = NumberRange.new(5, 16), ZOffset = 1 } },
}

-- Hit 3, every rarity: the rock breaking as the chest comes out (crystal shards, rock chunks,
-- dust and a ground ring). DigClient plays it with RarityFx[rarity].Burst on top, at the hole,
-- aimed up, with EmergeSoundId.
ChestFxPresets.ChestBurstBase = {
	{ template = "Frost", only = { "BrightBlueSharpShard", "BrightBlueDiolveShard" }, rotation = BACK, size = POINT, scale = 0.45, countMul = 1.5, tint = false, props = { SpreadAngle = Vector2.new(70, 70), ZOffset = 1 } },
	{ template = "FistShotVFX_2", only = { "Shards" }, size = POINT, scale = 0.6, countMul = 0.7, tint = ROCK, forceTint = true, props = { SpreadAngle = Vector2.new(75, 75), Acceleration = Vector3.new(0, -60, 0), ZOffset = 1 } },
	{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.9, countMul = 0.45, tint = DUST, forceTint = true, props = { Speed = NumberRange.new(5, 18), SpreadAngle = Vector2.new(85, 85) } },
	groundRing(0.35, nil, 0.03),
}

-- The chest lands (after popping out, when it appears on a plot, and under a character that pops
-- out of an opened chest). Played at its base, aimed up.
ChestFxPresets.ChestLand = {
	{ template = "SplashPuddle", only = { "Ground" }, rotation = TOP, scale = 0.2, tint = DUST_RING, forceTint = true, props = { LightEmission = 0.1, Brightness = 1.2 } },
	{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.7, countMul = 0.5, tint = DUST, forceTint = true, props = { Speed = NumberRange.new(4, 12), SpreadAngle = Vector2.new(90, 90) } },
	groundRing(0.25),
}

-- Loops (VfxPlayer.LoopPreset on the chest's PrimaryPart; ChestFx/DigClient centre them on the
-- chest and pass the rarity tint).

-- While the unlock timer runs (and while an emerged chest waits at the dig site): slow twinkles.
ChestFxPresets.IdleSparkle = {
	{ template = "Frost", only = { "Star" }, size = Vector3.new(4, 3, 3.5), rateMul = 0.12, props = {
		Size = seq(0, 0, 0.3, 1.1, 1, 0),
		Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
		Lifetime = life(0.6, 0.9),
	} },
}

-- Timer done, ready to open: twinkles drawn in toward the chest and a ring pulsing from its base.
ChestFxPresets.ReadyToOpen = {
	{ template = "Frost", only = { "Star" }, size = Vector3.new(7, 7, 7), rateMul = 0.4, props = {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = seq(0, 0, 0.3, 1.2, 1, 0),
		Speed = NumberRange.new(4, 6),
		Drag = 0,
		Lifetime = life(0.55, 0.75),
	} },
	-- anchor = "part": placed from the chest's PrimaryPart (its base), just above the floor
	{ template = "FistShotVFX_2", only = { "Shockwave1" }, size = POINT, anchor = "part", offset = Vector3.new(0, 0.15, 0), scale = 0.22, rateMul = 0.08, forceTint = true, props = {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.zero,
		TimeScale = 0.5,
		Brightness = 4,
	} },
}

-- Chest aura (ChestAura): every chest from the moment it emerges until it's opened, at the dig
-- site, carried and on a plot. What each rarity shows is in RarityFx below; these are the shared
-- parts and the limits that keep it light.
ChestFxPresets.ChestAura = {
	HaloImage = "rbxassetid://109223850052778", -- soft round glow (PBlue "ring" texture); the glow fills about the middle half
	HaloBehind = 0.3, -- the halo is pushed away from the camera by this times the chest size, so it stays behind it
	CullDistance = 150, -- studs from the camera; further chests switch their glow, light, sparkles and beam off
	MaxLights = 10, -- gem lights on at once (nearest chests first)
	MaxLightsMobile = 4,
	MaxSparkleChests = 10, -- chests whose sparkle loop runs at once (nearest first)
	MaxSparkleChestsMobile = 4,
	MobileRateMul = 0.5, -- sparkle rates on phones and tablets
}

-- Shimmer (ChestAura): every few seconds a quick Highlight flash over the chest in its glow colour.
ChestFxPresets.ChestShimmer = {
	Interval = NumberRange.new(3, 4), -- seconds between flashes (random in this range per flash)
	Seconds = 0.4, -- one flash: fade in, then out
	FillTransparency = 0.55, -- at the flash's brightest
	OutlineTransparency = 0.15,
}

-- Per-rarity effects. Tune here:
--   Glow      the halo behind the chest: Color, HaloScale (image size x chest size), HaloBrightness,
--             HaloTransparency { Peak, Low }, PulseSeconds, PulseSize, Flicker (0..1, random
--             flicker on top of the pulse), Sparkles (a loop preset around the chest, optional)
--   GemLight  the chest's one PointLight, on its Gem: Brightness { Peak, Low } pulsing with the glow,
--             Range. The Gem itself turns Neon in the rarity colour (TreasureModels).
--   SkyBeam   a beam from the chest straight up while it waits at the dig site or on a plot (off
--             while carried): Height, Width0 (bottom) / Width1 (top), Brightness, LightEmission
--             (low = solid colour against the bright sky; 1 = additive, washes out to white), PulseSeconds,
--             Transparency { Peak, Low }, AlwaysVisible (ignores CullDistance). nil = none.
--   Burst     hit 3 layers on top of ChestBurstBase; Shake { Strength, Seconds } for the digger;
--             SlowMo { Seconds, TimeScale } holds the moment (the burst plays slowed, the chest
--             and blocks wait) before everything flies.
--   Open      ChestOpen layers on the plot; OpenBeam = the thin white light beam; ScreenFlash
--             { Color, Seconds, Transparency } = a red screen-edge flash for the chest's owner.
--   Announce  Secret only: the server tells everyone (TreasureServer), clients show it in this colour.
ChestFxPresets.RarityFx = {
	Common = {
		Glow = { Color = TINT.Common, HaloScale = 2.4, HaloBrightness = 1.1, HaloTransparency = { Peak = 0.55, Low = 0.72 }, PulseSeconds = 2.5, PulseSize = 0.03, Flicker = 0 },
		GemLight = { Brightness = { Peak = 0.8, Low = 0.6 }, Range = 6 },
		SkyBeam = nil,
		Burst = { flash(0.3, nil, 0.15, 2) }, -- small white flash
		Shake = { Strength = 0.35, Seconds = 0.3 },
		Open = { flash(0.3, nil, 0.15, 2.5), twinkles(WHITE, 0.6, 10) }, -- small pop
		OpenBeam = false,
	},
	Epic = {
		Glow = { Color = TINT.Epic, HaloScale = 3.0, HaloBrightness = 1.6, HaloTransparency = { Peak = 0.2, Low = 0.6 }, PulseSeconds = 2.6, PulseSize = 0.08, Flicker = 0 },
		GemLight = { Brightness = { Peak = 1.4, Low = 1.0 }, Range = 9 },
		SkyBeam = { Height = 15, Width0 = 0.5, Width1 = 0.25, Brightness = 1.2, LightEmission = 0.15, PulseSeconds = 2.6, Transparency = { Peak = 0.15, Low = 0.45 } },
		Burst = { flash(0.35, TINT.Epic, 0.18, 2), starburst(0.1, TINT.Epic, 0.25), glowRing(0.1, TINT.Epic, 1.6, 0.9) }, -- purple flash + ring
		Shake = { Strength = 0.45, Seconds = 0.35 },
		Open = { flash(0.4, nil, 0.2, 4), glowRing(0.12, TINT.Epic, 0.8, 1.1), starburst(0.16, TINT.Epic, 0.3), rays(0.24, TINT.Epic, 0.6, 0.4), sparks(0.16, TINT.Epic, 0.8), twinkles(WHITE, 1.2, 16) },
		OpenBeam = true,
	},
	Legendary = {
		Glow = { Color = AURA_GOLD, HaloScale = 3.8, HaloBrightness = 2.2, HaloTransparency = { Peak = 0.05, Low = 0.25 }, PulseSeconds = 1.5, PulseSize = 0.07, Flicker = 0,
			-- slow golden sparkles drifting up around the chest
			Sparkles = {
				{ template = "Frost", only = { "Star" }, size = Vector3.new(3.6, 1.2, 3), offset = Vector3.new(0, -0.4, 0), rateMul = 0.12, tint = AURA_GOLD, forceTint = true, props = {
					EmissionDirection = Enum.NormalId.Top,
					Speed = NumberRange.new(0.8, 1.6),
					SpreadAngle = Vector2.new(20, 20),
					Acceleration = Vector3.new(0, 1.2, 0),
					Drag = 0,
					Size = seq(0, 0, 0.3, 0.7, 1, 0),
					Lifetime = life(1.4, 2.2),
					Brightness = 1.5,
				} },
			},
		},
		GemLight = { Brightness = { Peak = 2.0, Low = 1.4 }, Range = 12 },
		SkyBeam = { Height = 40, Width0 = 0.8, Width1 = 0.35, Brightness = 1.3, LightEmission = 0.15, PulseSeconds = 1.5, Transparency = { Peak = 0.1, Low = 0.4 } },
		-- gold flash, orange-gold rays and a golden glow behind the chest, big star, gold sparkles
		Burst = {
			flash(0.4, AURA_GOLD, 0.2, 2.5),
			rays(0.27, RAY_ORANGE, 1.4, 0.45),
			glowRing(0.11, TINT.Legendary, 2.4, 1.2),
			{ template = "Frost", only = { "Star" }, size = POINT, countMul = 0.125, tint = STAR_YELLOW, props = bigStar(9, 0.3, 4) },
			sparks(0.14, TINT.Legendary, 0.7),
			twinkles(TINT.Legendary, 1, 14),
		},
		Shake = { Strength = 0.6, Seconds = 0.4 },
		-- gold burst and gold confetti
		Open = {
			flash(0.45, nil, 0.2, 4), glowRing(0.14, TINT.Legendary, 0.8, 1.2), starburst(0.18, TINT.Legendary, 0.3), rays(0.28, TINT.Legendary, 0.6, 0.45),
			{ template = "Frost", only = { "Star" }, size = POINT, countMul = 0.125, tint = STAR_YELLOW, props = bigStar(10, 0.3, 4) },
			sparks(0.18, TINT.Legendary, 1), confetti(TINT.Legendary, 1, 0.4), confetti(WHITE, 0.4, 0.3),
		},
		OpenBeam = true,
	},
	Secret = {
		Glow = { Color = TINT.Secret, HaloScale = 3.6, HaloBrightness = 2.2, HaloTransparency = { Peak = 0.1, Low = 0.35 }, PulseSeconds = 1.0, PulseSize = 0.05, Flicker = 0.45,
			-- dark-red sparks drifting around the chest
			Sparkles = {
				{ template = "Frost", only = { "Star" }, size = Vector3.new(4, 2.5, 3.5), rateMul = 0.16, tint = DARK_RED, forceTint = true, props = {
					Speed = NumberRange.new(0.4, 1.4),
					SpreadAngle = Vector2.new(180, 180),
					Acceleration = Vector3.new(0, 0.8, 0),
					Drag = 0.5,
					Size = seq(0, 0, 0.25, 0.55, 1, 0),
					Lifetime = life(1.2, 2),
					Brightness = 1.2,
					LightEmission = 0,
				} },
			},
		},
		GemLight = { Brightness = { Peak = 2.4, Low = 1.4 }, Range = 14 },
		SkyBeam = { Height = 80, Width0 = 1.2, Width1 = 0.5, Brightness = 1.4, LightEmission = 0.15, PulseSeconds = 1.0, Transparency = { Peak = 0.05, Low = 0.35 }, AlwaysVisible = true },
		-- red flash, red starburst, a double glow ring and a double ground ring, red sparks
		Burst = {
			flash(0.5, TINT.Secret, 0.22, 3),
			starburst(0.14, TINT.Secret, 0.3),
			glowRing(0.12, TINT.Secret, 2, 1),
			glowRing(0.18, TINT.Secret, 2.6, 1, 0.15),
			groundRing(0.4, TINT.Secret, 0),
			groundRing(0.55, TINT.Secret, 0.15),
			sparks(0.16, TINT.Secret, 1.2),
		},
		Shake = { Strength = 1.1, Seconds = 0.6 },
		SlowMo = { Seconds = 0.15, TimeScale = 0.2 },
		-- red explosion: flash, rays, rings, sparks, dark-red smoke
		Open = {
			flash(0.55, TINT.Secret, 0.25, 4), rays(0.32, TINT.Secret, 0.6, 0.5), glowRing(0.16, TINT.Secret, 0.8, 1.2), starburst(0.2, TINT.Secret, 0.32),
			sparks(0.2, TINT.Secret, 1.2), groundRing(0.4, TINT.Secret, 0),
			{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.9, countMul = 0.6, tint = DARK_RED, forceTint = true, props = { Speed = NumberRange.new(6, 18), SpreadAngle = Vector2.new(80, 80) } },
		},
		OpenBeam = true,
		ScreenFlash = { Color = TINT.Secret, Seconds = 0.45, Transparency = 0.25 },
		Announce = { Color = TINT.Secret },
	},
}

-- Untouched mound: a twinkle on one of its blue crystals now and then (DigClient picks the crystal).
ChestFxPresets.MoundTwinkle = {
	{ template = "Frost", only = { "Star" }, size = POINT, countMul = 0.125, tint = false, props = {
		Speed = NumberRange.new(0, 0),
		Size = seq(0, 0, 0.35, 1.8, 1, 0),
		Lifetime = life(0.6),
		ZOffset = 1,
	} },
}

-- A new mound grows back in: a few dust puffs.
ChestFxPresets.MoundPuff = {
	{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.8, countMul = 0.5, tint = DUST, forceTint = true, props = {
		Speed = NumberRange.new(3, 9),
		SpreadAngle = Vector2.new(90, 90),
	} },
}

-- The effects for a rarity (Common when unknown).
function ChestFxPresets.ForRarity(rarityName)
	return ChestFxPresets.RarityFx[rarityName] or ChestFxPresets.RarityFx.Common
end

return ChestFxPresets
