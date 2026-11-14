-- AudioConfig: every sound in the game, keyed by its name in docs/00_Game_Plan/Audio_List.md
-- (source files in assets/SFX/SFX_<Key>.mp3). Change ids and volumes here only.
-- Volume guide (Audio_List): big moments 0.6-0.8, frequent sounds 0.3-0.4, loops 0.15-0.25.
--
-- AudioConfig.Play(key, where, opts) works on the server (the sound replicates to everyone) and on
-- clients (only that player hears it). `where`:
--   * a BasePart or Attachment: a 3D sound that follows it
--   * a Vector3: a 3D sound at that spot (it stays even if the thing that made it is removed)
--   * nil: a 2D sound (same loudness everywhere; SecretAnnounce)
-- opts.Looped = true keeps it playing until you call :Stop() / :Destroy() on the returned Sound.
-- opts.PlaybackSpeed overrides the speed; a sound with PitchRange gets a random speed in that range
-- every play (DigHit), so repeats don't sound robotic. FadeIn / FadeOut ramp a Sound's volume.
-- Placeholder ids (rbxassetid://0) play nothing.
--
-- StartAt (seconds) skips silence at the start of a file, so the sound lands on its moment.
-- Volume also evens out files that came out much quieter than the rest (measured with
-- PlaybackLoudness: most peak around 200; PickupDone peaks at 9, Open_Epic 34, ChestDrop 54).
-- Every sound is preloaded and kept loaded on each client, so plays aren't late (Preload).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local AudioConfig = {}

-- RollOff: 3D sounds are full volume within Min studs and fade out by Max.
local NEAR = { Min = 8, Max = 90 } -- chest and dig sounds
local FAR = { Min = 12, Max = 160 } -- boss sounds carry further

AudioConfig.Sounds = {
	-- Priority 1: the core loop
	DigHit = { Id = "rbxassetid://79276780678315", Volume = 0.35, PitchRange = { 0.95, 1.05 }, RollOff = NEAR }, -- pickaxe hits 1-2
	EmergeSoundId = { Id = "rbxassetid://125649136159228", Volume = 0.7, RollOff = NEAR }, -- hit 3, chest bursts out
	ChestLand = { Id = "rbxassetid://91242421295360", Volume = 0.5, StartAt = 0.25, RollOff = NEAR }, -- chest lands (dig site, plot)
	PickupHold = { Id = "rbxassetid://99639233150105", Volume = 0.4, RollOff = NEAR }, -- loops while holding E on the chest
	PickupDone = { Id = "rbxassetid://96798069357974", Volume = 8, RollOff = NEAR }, -- chest picked up (very quiet file: regenerate louder)
	WakeUpSoundId = { Id = "rbxassetid://78009492285312", Volume = 0.7, RollOff = FAR }, -- Boss_01 wakes
	TelegraphSoundId = { Id = "rbxassetid://123300737699319", Volume = 0.55, RollOff = FAR }, -- boss warning circle
	SkillHitSoundId = { Id = "rbxassetid://96778894932911", Volume = 0.75, RollOff = FAR }, -- boss shockwave lands
	ChestDrop = { Id = "rbxassetid://139704439924981", Volume = 1.6, RollOff = NEAR }, -- carrier hit, drops the chest (quiet file)

	-- Priority 2: opening by rarity (rarer = bigger)
	Open_Common = { Id = "rbxassetid://79338530438715", Volume = 0.45, RollOff = NEAR },
	Open_Epic = { Id = "rbxassetid://75234031266413", Volume = 2.2, StartAt = 0.14, RollOff = NEAR }, -- quiet file
	Open_Legendary = { Id = "rbxassetid://138288384813574", Volume = 0.7, RollOff = NEAR },
	Open_Secret = { Id = "rbxassetid://113798106466533", Volume = 0.8, RollOff = NEAR },
	CharacterAppear = { Id = "rbxassetid://123327428401145", Volume = 0.5, StartAt = 0.18, RollOff = NEAR }, -- character lands on the plot
	SecretAnnounce = { Id = "rbxassetid://80906199019263", Volume = 0.6, StartAt = 1.2 }, -- 2D, every player

	-- Priority 3: ambience and polish
	BeamHum = { Id = "rbxassetid://109788180216976", Volume = 0.15, RollOff = { Min = 6, Max = 45 } }, -- loops on Epic+ sky beams (ChestAura)
	MoundRespawn = { Id = "rbxassetid://71520234795064", Volume = 4, RollOff = NEAR }, -- a new mound grows back (quiet file: peaks at 19)
	CashTick = { Id = "rbxassetid://121758541053378", Volume = 0.3, RollOff = NEAR }, -- coin, once when a character lands on your plot (not on income)
	SafeZoneEnter = { Id = "rbxassetid://134919952997653", Volume = 0.5 }, -- 2D, you step into the SAFE ZONE
	UIClick = { Id = "rbxassetid://95740396502829", Volume = 0.3 }, -- 2D, any GUI button
	DesertAmbience = { Id = "rbxassetid://131963591216655", Volume = 2.5 }, -- 2D loop on Track_01; this file peaks at 11, so 2.5 sounds like a normal sound at about 0.15 (use 0.15 with a normal-loudness file)

	-- Carry loops: on the chest on a carrier's head, by rarity (TreasureServer). 3D, so nearby players
	-- hear it too; RollOff Max is how far it carries.
	Carry_Common = { Id = "rbxassetid://95132538649866", Volume = 0.2, RollOff = { Min = 6, Max = 60 } },
	Carry_Epic = { Id = "rbxassetid://109004894928009", Volume = 0.25, RollOff = { Min = 6, Max = 60 } },
	Carry_Legendary = { Id = "rbxassetid://129565902405958", Volume = 0.3, RollOff = { Min = 6, Max = 60 } },
	Carry_Secret = { Id = "rbxassetid://96978809939891", Volume = 0.35, RollOff = { Min = 8, Max = 90 } }, -- easier to notice
}

AudioConfig.CarryFadeSeconds = 0.3 -- carry loop fades in on pickup and out on drop, bank, death
AudioConfig.CoinDelaySeconds = 0.3 -- CashTick plays this long after CharacterAppear

-- Ambience loops (AudioClient): each plays while the local player stands over its zone part
-- (path under Workspace; up to ExtraHeight studs above it) and fades in/out over FadeSeconds.
-- Track_01 = the desert TreasureField where Boss_01's dig site is.
AudioConfig.Ambience = {
	DesertAmbience = { Zone = { "TreasureGame", "TreasureField" }, ExtraHeight = 80, FadeSeconds = 1 },
}

local function isPlaceholder(id)
	return type(id) ~= "string" or id == "" or id:match("^rbxassetid://0+$") ~= nil
end

-- Plays sound `key` (see the header). Returns the Sound, or nil for a placeholder / unknown key.
function AudioConfig.Play(key, where, opts)
	opts = opts or {}
	local def = AudioConfig.Sounds[key]
	if not def then
		warn(("[AudioConfig] unknown sound %s"):format(tostring(key)))
		return nil
	end
	if isPlaceholder(def.Id) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. key
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.Looped = opts.Looped == true
	if opts.PlaybackSpeed then
		sound.PlaybackSpeed = opts.PlaybackSpeed
	elseif def.PitchRange then
		sound.PlaybackSpeed = def.PitchRange[1] + math.random() * (def.PitchRange[2] - def.PitchRange[1])
	end
	local holder
	if typeof(where) == "Vector3" then
		holder = Instance.new("Attachment") -- a fixed spot in the world
		holder.Name = "SfxSpot_" .. key
		holder.Parent = Workspace.Terrain
		holder.WorldPosition = where
		where = holder
	end
	if where and def.RollOff then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = def.RollOff.Min
		sound.RollOffMaxDistance = def.RollOff.Max
	end
	sound.Parent = where or SoundService -- no parent part: 2D
	if def.StartAt then
		sound.TimePosition = def.StartAt
	end
	sound:Play()
	if not sound.Looped then
		local cleanup = holder or sound
		sound.Ended:Connect(function()
			cleanup:Destroy()
		end)
		Debris:AddItem(cleanup, 10) -- in case Ended never fires (e.g. the asset failed to load)
	elseif holder then
		sound.Destroying:Connect(function()
			holder:Destroy()
		end)
	end
	return sound
end

-- Ramps a playing Sound from silent up to its AudioConfig volume (or the given volume) over the given seconds.
function AudioConfig.FadeIn(sound, seconds, volume)
	local key = sound.Name:gsub("^Sfx_", "")
	local def = AudioConfig.Sounds[key]
	local target = volume or (def and def.Volume) or sound.Volume
	sound.Volume = 0
	TweenService:Create(sound, TweenInfo.new(seconds), { Volume = target }):Play()
end

-- Fades a Sound out over the given seconds, then removes it. It is first moved to a fixed spot where it
-- is now, so it keeps fading even if the part it was on is about to be destroyed (a chest that
-- was dropped or banked).
function AudioConfig.FadeOut(sound, seconds)
	if not sound or not sound.Parent then
		return
	end
	local parent = sound.Parent
	local position = (parent:IsA("BasePart") and parent.Position) or (parent:IsA("Attachment") and parent.WorldPosition) or nil
	local holder
	if position then
		holder = Instance.new("Attachment")
		holder.Name = "SfxFade_" .. sound.Name
		holder.Parent = Workspace.Terrain
		holder.WorldPosition = position
		sound.Parent = holder
	end
	local tween = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
		if holder then
			holder:Destroy()
		end
	end)
	tween:Play()
end

-- Loads every sound up front (clients do this by themselves when they start), so the first
-- play doesn't wait for a download (otherwise about 0.5-1s late). The loaded copies stay in
-- SoundService.AudioCache, silent: while one copy of an id is loaded, every new Sound with that id
-- is ready at once (measured: plays within 0.02s). Throwaway preload copies don't keep it cached.
function AudioConfig.Preload()
	if SoundService:FindFirstChild("AudioCache") then
		return
	end
	local cache = Instance.new("Folder")
	cache.Name = "AudioCache"
	cache.Parent = SoundService
	local sounds = {}
	for key, def in pairs(AudioConfig.Sounds) do
		if not isPlaceholder(def.Id) then
			local sound = Instance.new("Sound")
			sound.Name = key
			sound.SoundId = def.Id
			sound.Volume = 0
			sound.Parent = cache
			table.insert(sounds, sound)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(sounds)
	end)
end

if RunService:IsClient() and RunService:IsRunning() then
	task.spawn(AudioConfig.Preload)
end

return AudioConfig
