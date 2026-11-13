-- Roll: server-only randomness for chests. The client never rolls.
--   1. Rarity(weights)        -> rarity rolled when a dig completes (boss RarityWeights)
--   2. Character(series, rarity) -> one character of that rarity, equal chance
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))

local Roll = {}

local rng = Random.new()

function Roll.Rarity(weights)
	local order = {}
	local total = 0
	for rarity, weight in pairs(weights) do
		if weight > 0 then
			table.insert(order, rarity)
			total += weight
		end
	end
	-- Fixed order so the same roll value always maps to the same rarity.
	table.sort(order, function(a, b)
		return AnimeConfig.Rarities[a].Order < AnimeConfig.Rarities[b].Order
	end)

	local pick = rng:NextNumber() * total
	for _, rarity in ipairs(order) do
		pick -= weights[rarity]
		if pick < 0 then
			return rarity
		end
	end
	return order[#order]
end

function Roll.Character(seriesId, rarity)
	local pool = {}
	for _, entry in ipairs(AnimeConfig.GetSeries(seriesId).Characters) do
		if entry.Rarity == rarity then
			table.insert(pool, entry)
		end
	end
	assert(#pool > 0, ("Roll: %s has no %s characters"):format(seriesId, rarity))
	return pool[rng:NextInteger(1, #pool)]
end

return Roll
