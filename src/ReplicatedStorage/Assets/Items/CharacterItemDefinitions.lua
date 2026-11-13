-- CharacterItemDefinitions: adds every series character from AnimeConfig to
-- ItemDefinitions so the existing inventory UI can show them.
-- DefinitionId = CharacterId. Called from ItemDefinitions before it freezes:
--   require(script.Parent:WaitForChild("CharacterItemDefinitions"))(ItemDefinitions)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))

local SORT_BASE = 1000

return function(definitions)
	for seriesId, series in pairs(AnimeConfig.Series) do
		for index, entry in ipairs(series.Characters) do
			definitions[entry.CharacterId] = {
				Theme = seriesId,
				SeriesName = series.DisplayName,
				DisplayName = AnimeConfig.GetCharacterName(entry),
				Rarity = entry.Rarity,
				Model = entry.CharacterId,
				Icon = "", -- TODO: character icon
				Category = "Character",
				Description = ("+%d Cash/s on your plot"):format(entry.IncomePerSecond),
				MaxStack = 1,
				CanEquip = false,
				SortOrder = SORT_BASE + AnimeConfig.Rarities[entry.Rarity].Order * 100 + index,
			}
		end
	end
end
