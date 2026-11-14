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
-- Placeholder ids (rbxassetid://0) play nothing.
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local AudioConfig = {}

-- RollOff: 3D sounds are full volume within Min studs and fade out by Max.
local NEAR = { Min = 8, Max = 90 } -- chest and dig sounds
local FAR = { Min = 12, Max = 160 } -- boss sounds carry further

AudioConfig.Sounds = {
	-- Priority 1: the core loop
	DigHit = { Id = "rbxassetid://79276780678315", Volume = 0.35, RollOff = NEAR }, -- pickaxe hits 1-2
	EmergeSoundId = { Id = "rbxassetid://125649136159228", Volume = 0.7, RollOff = NEAR }, -- hit 3, chest bursts out
	ChestLand = { Id = "rbxassetid://91242421295360", Volume = 0.5, RollOff = NEAR }, -- chest lands (dig site, plot)
	PickupHold = { Id = "rbxassetid://99639233150105", Volume = 0.4, RollOff = NEAR }, -- loops while holding E on the chest
	PickupDone = { Id = "rbxassetid://96798069357974", Volume = 0.55, RollOff = NEAR }, -- chest picked up
	WakeUpSoundId = { Id = "rbxassetid://78009492285312", Volume = 0.7, RollOff = FAR }, -- Boss_01 wakes
	TelegraphSoundId = { Id = "rbxassetid://123300737699319", Volume = 0.55, RollOff = FAR }, -- boss warning circle
	SkillHitSoundId = { Id = "rbxassetid://96778894932911", Volume = 0.75, RollOff = FAR }, -- boss shockwave lands
	ChestDrop = { Id = "rbxassetid://139704439924981", Volume = 0.6, RollOff = NEAR }, -- carrier hit, drops the chest

	-- Priority 2: opening by rarity (rarer = bigger)
	Open_Common = { Id = "rbxassetid://79338530438715", Volume = 0.45, RollOff = NEAR },
	Open_Epic = { Id = "rbxassetid://75234031266413", Volume = 0.55, RollOff = NEAR },
	Open_Legendary = { Id = "rbxassetid://138288384813574", Volume = 0.7, RollOff = NEAR },
	Open_Secret = { Id = "rbxassetid://113798106466533", Volume = 0.8, RollOff = NEAR },
	CharacterAppear = { Id = "rbxassetid://123327428401145", Volume = 0.5, RollOff = NEAR }, -- character lands on the plot
	SecretAnnounce = { Id = "rbxassetid://80906199019263", Volume = 0.6 }, -- 2D, every player

	-- Priority 3: ambience and polish (not made yet)
	BeamHum = { Id = "rbxassetid://0", Volume = 0.2, RollOff = NEAR },
	MoundRespawn = { Id = "rbxassetid://0", Volume = 0.4, RollOff = NEAR },
	CashTick = { Id = "rbxassetid://0", Volume = 0.3 },
	SafeZoneEnter = { Id = "rbxassetid://0", Volume = 0.5 },
	UIClick = { Id = "rbxassetid://0", Volume = 0.3 },
	DesertAmbience = { Id = "rbxassetid://0", Volume = 0.2 },
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

return AudioConfig
