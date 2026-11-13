-- AnimeConfig
-- Single source of truth for bosses, chests, characters and the economy.
-- Boss blocks mirror docs/00_Game_Plan/Boss_XX.md; series blocks mirror
-- docs/00_Game_Plan/Series_XX_Characters.md.
--
-- Adding a boss (e.g. Boss_02):
--   1. Copy the Boss_01 block and change BossId / DisplayName / Rarity / Stage.
--   2. Make it harder: raise WalkSpeed, lower TelegraphWarningSeconds and
--      SkillCooldownSeconds, raise SkillRadiusStuds, or set SkillPattern to a
--      harder pattern registered in ServerScriptService.TreasureGame.SkillPatterns.
--   3. Set OpensInto to its series and give it RarityWeights.
--   4. Append the id to AnimeConfig.BossOrder.
--   5. In Studio, add a dig site under Workspace.TreasureGame.DigSites with the
--      attribute BossId = "Boss_02" (a DigMound part + a BossSpawn part).

local AnimeConfig = {}

-- World layout the scripts look for.
AnimeConfig.World = {
	GameFolderName = "TreasureGame", -- Workspace.TreasureGame
	SafeZoneFolderName = "SafeZones", -- every part inside counts as SAFE ZONE
	DigSitesFolderName = "DigSites",
	EffectsFolderName = "Effects",
	-- Base plots: a part named PlotPartName anywhere under this path.
	PlotsPath = { "Lobby", "Places" },
	PlotPartName = "Plot",
	-- Models load by name; a missing model becomes a grey dummy with a name label.
	ModelsFolderName = "Models", -- ReplicatedStorage.Models
	BossModelsFolderName = "Bosses", -- Models/Bosses/<BossId>
	CharacterModelsFolderName = "Characters", -- Models/Characters/<SeriesId>/<CharacterId>
}

AnimeConfig.Economy = {
	StartingCash = 0,
	PlotCharacterSlots = 8, -- characters on a plot; more go to the inventory (storage only)
	IncomeTickSeconds = 1, -- every tick, each plot character pays IncomePerSecond * tick
}

AnimeConfig.Saving = {
	DataStoreName = "PlayerData_v1", -- saves Cash, characters and unopened chests
	AutosaveSeconds = 60,
}

AnimeConfig.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(200, 200, 200) },
	Epic = { Order = 2, Color = Color3.fromRGB(170, 80, 255) },
	Legendary = { Order = 3, Color = Color3.fromRGB(255, 190, 40) },
	Secret = { Order = 4, Color = Color3.fromRGB(255, 60, 90) },
}

-- Named colors used by spec fields such as TelegraphColor.
AnimeConfig.Colors = {
	Red = Color3.fromRGB(255, 40, 40),
	Orange = Color3.fromRGB(255, 140, 30),
	Purple = Color3.fromRGB(170, 60, 255),
	Blue = Color3.fromRGB(40, 120, 255),
}

-- Temporary test values: IncomePerSecond and UnlockTimeSeconds are TBD in the docs.
local TEMP_INCOME_PER_SECOND = {
	Common = 10, -- TODO(balance): IncomePerSecond is TBD in Series_01_Characters.md
	Epic = 30, -- TODO(balance): IncomePerSecond is TBD in Series_01_Characters.md
	Legendary = 100, -- TODO(balance): IncomePerSecond is TBD in Series_01_Characters.md
	Secret = 500, -- TODO(balance): IncomePerSecond is TBD in Series_01_Characters.md
}

local function character(characterId, rarity)
	return {
		CharacterId = characterId, -- also the model name under Models/Characters/<SeriesId>
		DisplayName = "TBD", -- TBD shows the CharacterId instead
		Rarity = rarity,
		IncomePerSecond = TEMP_INCOME_PER_SECOND[rarity],
	}
end

AnimeConfig.Series = {
	Series_01 = {
		SeriesId = "Series_01",
		DisplayName = "Series 01", -- TODO: real series name
		UnlockTimeSeconds = {
			Common = 10, -- TODO(balance): UnlockTimeSeconds is TBD in Series_01_Characters.md
			Epic = 30, -- TODO(balance): UnlockTimeSeconds is TBD in Series_01_Characters.md
			Legendary = 60, -- TODO(balance): UnlockTimeSeconds is TBD in Series_01_Characters.md
			Secret = 120, -- TODO(balance): UnlockTimeSeconds is TBD in Series_01_Characters.md
		},
		Characters = {
			character("S01_Common_01", "Common"),
			character("S01_Common_02", "Common"),
			character("S01_Common_03", "Common"),
			character("S01_Epic_01", "Epic"),
			character("S01_Epic_02", "Epic"),
			character("S01_Epic_03", "Epic"),
			character("S01_Legendary_01", "Legendary"),
			character("S01_Legendary_02", "Legendary"),
			character("S01_Legendary_03", "Legendary"),
			character("S01_Secret_01", "Secret"),
			character("S01_Secret_02", "Secret"),
			character("S01_Secret_03", "Secret"),
		},
	},
}

AnimeConfig.BossOrder = { "Boss_01" }

AnimeConfig.Bosses = {
	Boss_01 = {
		-- 1. General & Treasure Info
		BossId = "Boss_01",
		DisplayName = "Starter Guardian",
		AnimeSeries = "Series_01",
		Rarity = "Common", -- boss tier label; the chest rarity comes from RarityWeights
		Stage = 1, -- Main_Index: Stage 1 / Anime Series 1
		TreasureName = "Tier 1 Anime Treasure",
		DigTimeSeconds = 3,

		-- 2. Wake-Up, Chase & Telegraph Skill
		DefaultState = "Sleeping",
		TriggerCondition = "OnDigCompleted",
		WalkSpeed = 18, -- player default is 16, so the boss slowly gains
		ChaseStopInSafeZone = true,
		ReturnToSleepSeconds = 5.0, -- boss falls asleep this long after the chase ends
		SkillPattern = "CircleTelegraph",
		SkillCooldownSeconds = 3.5,
		TelegraphWarningSeconds = 1.5,
		SkillRadiusStuds = 18,
		SkillDamage = 25, -- 4 hits to kill a 100 HP player
		DropTreasureOnHit = true,

		-- 4. Assets, VFX & SFX
		-- Placeholders are skipped at runtime (see IsPlaceholderAsset).
		BossModelName = "TBD", -- TODO: real boss model (loads Models/Bosses/Boss_01; grey-box until then)
		TreasureModelName = "TBD", -- TODO: real treasure model (gold block until then)
		TelegraphColor = "Red",
		DigSoundId = "rbxassetid://0", -- TODO: dig sound
		WakeUpSoundId = "rbxassetid://0", -- TODO: boss wake-up roar
		TelegraphSoundId = "rbxassetid://0", -- TODO: telegraph warning sound
		SkillHitSoundId = "rbxassetid://0", -- TODO: skill impact sound
		SkillVFXName = "TBD", -- TODO: skill strike VFX

		-- 5. Chest Opening
		OpensInto = "Series_01",
		OpenKey = "E",
		OpenTimeSeconds = 2,
		RarityWeights = { Common = 700, Epic = 250, Legendary = 45, Secret = 5 }, -- rolled when the dig completes
	},
}

-- Lookups -----------------------------------------------------------------

local characterIndex = {} -- [CharacterId] = { Character = ..., SeriesId = ... }
for seriesId, series in pairs(AnimeConfig.Series) do
	for _, entry in ipairs(series.Characters) do
		assert(not characterIndex[entry.CharacterId], "AnimeConfig: duplicate CharacterId " .. entry.CharacterId)
		characterIndex[entry.CharacterId] = { Character = entry, SeriesId = seriesId }
	end
end

function AnimeConfig.GetBoss(bossId)
	local boss = AnimeConfig.Bosses[bossId]
	assert(boss, ("AnimeConfig: no boss with id %s"):format(tostring(bossId)))
	return boss
end

function AnimeConfig.GetSeries(seriesId)
	local series = AnimeConfig.Series[seriesId]
	assert(series, ("AnimeConfig: no series with id %s"):format(tostring(seriesId)))
	return series
end

-- Returns character, seriesId (or nil if the id is unknown).
function AnimeConfig.GetCharacter(characterId)
	local found = characterIndex[characterId]
	if found then
		return found.Character, found.SeriesId
	end
	return nil
end

function AnimeConfig.GetCharacterName(entry)
	if entry.DisplayName == nil or entry.DisplayName == "TBD" then
		return entry.CharacterId
	end
	return entry.DisplayName
end

function AnimeConfig.GetColor(name)
	return AnimeConfig.Colors[name] or AnimeConfig.Colors.Red
end

-- "rbxassetid://0" / "TBD" mean "not made yet": skip instead of erroring.
function AnimeConfig.IsPlaceholderAsset(id)
	return id == nil or id == "" or id == "TBD" or id == "rbxassetid://0"
end

-- Validation (runs once on require) ----------------------------------------

local REQUIRED_KEYS = {
	"BossId", "DisplayName", "Rarity", "TreasureName", "DigTimeSeconds",
	"WalkSpeed", "ReturnToSleepSeconds", "SkillPattern", "SkillCooldownSeconds",
	"TelegraphWarningSeconds", "SkillRadiusStuds", "SkillDamage",
	"OpensInto", "OpenTimeSeconds", "RarityWeights",
}

for id, boss in pairs(AnimeConfig.Bosses) do
	for _, key in ipairs(REQUIRED_KEYS) do
		assert(boss[key] ~= nil, ("AnimeConfig: %s is missing %s"):format(id, key))
	end
	assert(boss.BossId == id, ("AnimeConfig: key %s does not match BossId %s"):format(id, boss.BossId))
	assert(AnimeConfig.Rarities[boss.Rarity], ("AnimeConfig: %s has unknown Rarity %s"):format(id, boss.Rarity))
	local series = AnimeConfig.Series[boss.OpensInto]
	assert(series, ("AnimeConfig: %s opens into unknown series %s"):format(id, tostring(boss.OpensInto)))
	local total = 0
	for rarity, weight in pairs(boss.RarityWeights) do
		assert(AnimeConfig.Rarities[rarity], ("AnimeConfig: %s RarityWeights has unknown rarity %s"):format(id, rarity))
		assert(type(weight) == "number" and weight >= 0, ("AnimeConfig: %s weight for %s must be >= 0"):format(id, rarity))
		total += weight
		if weight > 0 then
			assert(type(series.UnlockTimeSeconds[rarity]) == "number",
				("AnimeConfig: %s has no UnlockTimeSeconds for %s"):format(boss.OpensInto, rarity))
			local hasCharacter = false
			for _, entry in ipairs(series.Characters) do
				if entry.Rarity == rarity then
					hasCharacter = true
					break
				end
			end
			assert(hasCharacter, ("AnimeConfig: %s has no %s characters for %s"):format(boss.OpensInto, rarity, id))
		end
	end
	assert(total > 0, ("AnimeConfig: %s RarityWeights add up to 0"):format(id))
end

for seriesId, series in pairs(AnimeConfig.Series) do
	for _, entry in ipairs(series.Characters) do
		assert(AnimeConfig.Rarities[entry.Rarity], ("AnimeConfig: %s has unknown rarity %s"):format(entry.CharacterId, tostring(entry.Rarity)))
		assert(type(entry.IncomePerSecond) == "number", ("AnimeConfig: %s in %s needs IncomePerSecond"):format(entry.CharacterId, seriesId))
	end
end

return AnimeConfig
