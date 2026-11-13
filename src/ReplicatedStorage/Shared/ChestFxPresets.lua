-- ChestFxPresets: which VFX layers play at each moment of the dig/chest sequence.
-- Tune here only. Emitter names come from the KitsBlox packs in ReplicatedStorage/VFX
-- (docs/00_Game_Plan/VFX_Plan.md lists what each emitter looks like).
--
-- Look (from the reference picture): a pink-white starburst and a big yellow star on each pickaxe
-- hit with tan rock chips and blue crystal splinters flying; on hit 3 the chest bursts out with a
-- flash, golden rays, a golden glow and sparks; opening gives a rarity-coloured flash, cyan cubes,
-- sparkles and (ChestFx) a thin white light beam.
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

ChestFxPresets.RarityTint = {
	Common = Color3.fromRGB(190, 225, 255), -- ice white-blue
	Epic = Color3.fromRGB(185, 120, 255), -- purple
	Legendary = Color3.fromRGB(255, 205, 80), -- gold
	Secret = Color3.fromRGB(255, 95, 200), -- hot pink
}

-- Burst aims: turn each pack's emission face onto the preset's LookVector.
local BACK = Vector3.new(0, 180, 0)
local LEFT = Vector3.new(0, -90, 0)
local TOP = Vector3.new(-90, 0, 0)
local POINT = Vector3.new(0.1, 0.1, 0.1)

local FLASH_PINK = Color3.fromRGB(255, 120, 200)
local STAR_YELLOW = Color3.fromRGB(255, 214, 50)
local GOLD = Color3.fromRGB(255, 190, 40)
local RAY_ORANGE = Color3.fromRGB(255, 150, 20) -- rays stand out against the golden glow
local ROCK = Color3.fromRGB(176, 146, 104) -- a little darker than the mound so chips show on the sand
local DUST = Color3.fromRGB(252, 248, 238) -- cream-white cartoon puffs
local DUST_RING = Color3.fromRGB(196, 168, 124)
local CYAN = Color3.fromRGB(70, 230, 255)
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

-- Hit 3: the chest bursts out of the rock. Played at the hole, aimed up. Plays with EmergeSoundId.
ChestFxPresets.ChestBurst = {
	-- white-hot flash and a pink-white starburst from the hole (drawn behind the chest)
	{ template = "FistShotVFX_2", only = { "GlowImpact" }, size = POINT, scale = 0.4, tint = false, props = { Lifetime = life(0.18), Brightness = 2.5, ZOffset = 2 } },
	{ template = "PBlue", only = { "Impact356" }, rotation = TOP, scale = 0.13, ignoreDelay = true, tint = FLASH_PINK, props = { Lifetime = life(0.3), ZOffset = 0.5 } },
	-- orange-gold rays and a golden glow behind the chest (raised so the ground doesn't cut them)
	{ template = "PBlue", only = { "Impact550" }, offset = Vector3.new(0, 0, -1.4), rotation = TOP, scale = 0.27, ignoreDelay = true, tint = RAY_ORANGE, props = { Lifetime = life(0.45), Brightness = 1.3, ZOffset = -1 } },
	{ template = "PBlue", only = { "ring" }, offset = Vector3.new(0, 0, -2.4), rotation = TOP, scale = 0.11, ignoreDelay = true, tint = GOLD, props = {
		Transparency = seq(0, 0.25, 0.4, 0.45, 1, 1),
		Lifetime = life(1.2),
		ZOffset = -1.5,
	} },
	-- big yellow star and golden sparkles shooting out
	{ template = "Frost", only = { "Star" }, size = POINT, countMul = 0.125, tint = STAR_YELLOW, props = bigStar(9, 0.3, 4) },
	{ template = "PBlue", only = { "RedFire2" }, rotation = TOP, scale = 0.14, ignoreDelay = true, countMul = 0.7, tint = GOLD, props = { Brightness = 1.5, ZOffset = 1 } },
	-- blue crystal shards (they stay blue, like the crystals in the rock) and tan rock chunks
	{ template = "Frost", only = { "BrightBlueSharpShard", "BrightBlueDiolveShard" }, rotation = BACK, size = POINT, scale = 0.45, countMul = 1.5, tint = false, props = { SpreadAngle = Vector2.new(70, 70), ZOffset = 1 } },
	{ template = "FistShotVFX_2", only = { "Shards" }, size = POINT, scale = 0.6, countMul = 0.7, tint = ROCK, forceTint = true, props = { SpreadAngle = Vector2.new(75, 75), Acceleration = Vector3.new(0, -60, 0), ZOffset = 1 } },
	-- dust puffs and a white shockwave ring along the ground
	{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.9, countMul = 0.45, tint = DUST, forceTint = true, props = { Speed = NumberRange.new(5, 18), SpreadAngle = Vector2.new(85, 85) } },
	{ template = "FistShotVFX_2", only = { "Shockwave1" }, rotation = TOP, size = POINT, scale = 0.35, delay = 0.03, tint = false, props = {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.zero,
	} },
}

-- The chest lands (after popping out, and when it appears on a plot). Played at its base, aimed up.
ChestFxPresets.ChestLand = {
	{ template = "SplashPuddle", only = { "Ground" }, rotation = TOP, scale = 0.2, tint = DUST_RING, forceTint = true, props = { LightEmission = 0.1, Brightness = 1.2 } },
	{ template = "FistShotVFX_2", only = { "BALLLSLSLSL2" }, size = POINT, scale = 0.7, countMul = 0.5, tint = DUST, forceTint = true, props = { Speed = NumberRange.new(4, 12), SpreadAngle = Vector2.new(90, 90) } },
	{ template = "FistShotVFX_2", only = { "Shockwave1" }, rotation = TOP, size = POINT, scale = 0.25, tint = false, props = {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.zero,
	} },
}

-- Opening on the plot. Played at the chest, aimed up; layers without their own tint get
-- RarityTint[rarity]. ChestFx adds the thin white light beam.
ChestFxPresets.ChestOpen = {
	-- white flash and a rarity-coloured glow
	{ template = "FistShotVFX_2", only = { "GlowImpact" }, size = POINT, scale = 0.4, tint = false, props = { Lifetime = life(0.2), Brightness = 4, ZOffset = 2 } },
	{ template = "PBlue", only = { "ring" }, offset = Vector3.new(0, 0, -0.8), rotation = TOP, scale = 0.12, ignoreDelay = true, props = {
		Transparency = seq(0, 0.2, 0.5, 0.5, 1, 1),
		Lifetime = life(1.1),
		ZOffset = -1.5,
	} },
	-- rarity-coloured starburst, rays behind the chest, big star and sparks
	{ template = "PBlue", only = { "Impact356" }, rotation = TOP, scale = 0.16, ignoreDelay = true, props = { Lifetime = life(0.3), Brightness = 1.5, ZOffset = 2.5 } },
	{ template = "PBlue", only = { "Impact550" }, offset = Vector3.new(0, 0, -0.6), rotation = TOP, scale = 0.24, ignoreDelay = true, props = { Lifetime = life(0.4), Brightness = 1.5, ZOffset = -1 } },
	{ template = "Frost", only = { "Star" }, size = POINT, countMul = 0.125, props = bigStar(10, 0.3, 4) },
	{ template = "PBlue", only = { "RedFire2" }, rotation = TOP, scale = 0.16, ignoreDelay = true, countMul = 0.8, props = { Brightness = 1.5, ZOffset = 1 } },
	-- cyan cubes tumbling up and falling back (the pack's rock chips, made square-ish and slow)
	{ template = "FistShotVFX_2", only = { "Shards" }, size = POINT, countMul = 0.6, tint = CYAN, forceTint = true, props = {
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Squash = seq(0, 0, 1, 0),
		Size = seq(0, 0.65, 0.8, 0.65, 1, 0),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 1.5,
		Acceleration = Vector3.new(0, -45, 0),
		Lifetime = life(0.9, 1.2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 0.2,
		Brightness = 1.2,
		ZOffset = 1,
	} },
	-- white twinkles flying out
	{ template = "Frost", only = { "Star" }, rotation = LEFT, size = POINT, countMul = 1.5, tint = WHITE, props = {
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 3,
		Size = seq(0, 0, 0.2, 1.4, 1, 0),
		Lifetime = life(0.6, 0.9),
		ZOffset = 1,
	} },
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

return ChestFxPresets
