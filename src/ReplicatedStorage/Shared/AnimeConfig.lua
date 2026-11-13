-- AnimeConfig
-- Single source of truth for treasure + boss tuning.
-- Each boss block mirrors its Obsidian spec (Test/Boss_XX.md) key-for-key.
--
-- Adding a boss (e.g. Boss_02):
--   1. Copy the Boss_01 block and change BossId / DisplayName / Rarity / Stage.
--   2. Make it harder: raise WalkSpeed, lower TelegraphWarningSeconds and
--      SkillCooldownSeconds, raise SkillRadiusStuds, or set SkillPattern to a
--      harder pattern registered in ServerScriptService.TreasureGame.SkillPatterns.
--   3. Append the id to AnimeConfig.BossOrder.
--   4. In Studio, add a dig site under Workspace.TreasureGame.DigSites with the
--      attribute BossId = "Boss_02" (a DigMound part + a BossSpawn part).

local AnimeConfig = {}

-- World layout the server scripts look for.
AnimeConfig.World = {
	GameFolderName = "TreasureGame", -- Workspace.TreasureGame
	SafeZoneFolderName = "SafeZones", -- every part inside counts as SAFE ZONE
	DigSitesFolderName = "DigSites",
	EffectsFolderName = "Effects",
	-- Base plots: a part named PlotPartName anywhere under this path banks the treasure.
	PlotsPath = { "Lobby", "Places" },
	PlotPartName = "Plot",
}

AnimeConfig.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(200, 200, 200) },
	Rare = { Order = 2, Color = Color3.fromRGB(70, 140, 255) },
	Epic = { Order = 3, Color = Color3.fromRGB(170, 80, 255) },
	Legend = { Order = 4, Color = Color3.fromRGB(255, 190, 40) },
	Secret = { Order = 5, Color = Color3.fromRGB(255, 60, 90) },
}

-- Named colors used by spec fields such as TelegraphColor.
AnimeConfig.Colors = {
	Red = Color3.fromRGB(255, 40, 40),
	Orange = Color3.fromRGB(255, 140, 30),
	Purple = Color3.fromRGB(170, 60, 255),
	Blue = Color3.fromRGB(40, 120, 255),
}

AnimeConfig.BossOrder = { "Boss_01" }

AnimeConfig.Bosses = {
	Boss_01 = {
		-- 1. General & Treasure Info
		BossId = "Boss_01",
		DisplayName = "Starter Guardian",
		AnimeSeries = "Series_01",
		Rarity = "Common",
		Stage = 1, -- Main_Index: Stage 1 / Anime Series 1
		TreasureName = "Tier 1 Anime Treasure",
		DigTimeSeconds = 3,
		IncomePerSecond = 10,
		SellPrice = 100,

		-- 2. Wake-Up, Chase & Telegraph Skill
		DefaultState = "Sleeping",
		TriggerCondition = "OnDigCompleted",
		WalkSpeed = 16,
		ChaseStopInSafeZone = true,
		ReturnToSleepSeconds = 8.0, -- max time to walk home before snapping back asleep
		SkillPattern = "CircleTelegraph",
		SkillCooldownSeconds = 3.5,
		TelegraphWarningSeconds = 1.5,
		SkillRadiusStuds = 18,
		SkillDamage = 100,
		DropTreasureOnHit = true,

		-- 4. Assets, VFX & SFX
		BossModelName = "TBD",
		TreasureModelName = "TBD",
		TelegraphColor = "Red",
		DigSoundId = "rbxassetid://0",
		WakeUpSoundId = "rbxassetid://0",
		TelegraphSoundId = "rbxassetid://0",
		SkillHitSoundId = "rbxassetid://0",
		SkillVFXName = "TBD",
	},
}

local REQUIRED_KEYS = {
	"BossId", "DisplayName", "Rarity", "TreasureName", "DigTimeSeconds",
	"WalkSpeed", "ReturnToSleepSeconds", "SkillPattern", "SkillCooldownSeconds",
	"TelegraphWarningSeconds", "SkillRadiusStuds", "SkillDamage",
}

for id, boss in pairs(AnimeConfig.Bosses) do
	for _, key in ipairs(REQUIRED_KEYS) do
		assert(boss[key] ~= nil, ("AnimeConfig: %s is missing %s"):format(id, key))
	end
	assert(boss.BossId == id, ("AnimeConfig: key %s does not match BossId %s"):format(id, boss.BossId))
	assert(AnimeConfig.Rarities[boss.Rarity], ("AnimeConfig: %s has unknown Rarity %s"):format(id, boss.Rarity))
end

function AnimeConfig.GetBoss(bossId)
	local boss = AnimeConfig.Bosses[bossId]
	assert(boss, ("AnimeConfig: no boss with id %s"):format(tostring(bossId)))
	return boss
end

function AnimeConfig.GetColor(name)
	return AnimeConfig.Colors[name] or AnimeConfig.Colors.Red
end

-- "rbxassetid://0" / "TBD" mean "not made yet": skip instead of erroring.
function AnimeConfig.IsPlaceholderAsset(id)
	return id == nil or id == "" or id == "TBD" or id == "rbxassetid://0"
end

return AnimeConfig
