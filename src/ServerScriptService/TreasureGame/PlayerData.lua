-- PlayerData: loads and saves each player's Cash, characters and unopened chests.
-- Data shape:
--   { Version = 1, Cash = number,
--     Characters = { { Id, CharacterId, Location = "Plot" | "Inventory", Slot = number?, AcquiredAt } },
--     Chests = { { Id, BossId, Rarity, UnlockAt = os.time() seconds } } }
-- If loading fails (e.g. Studio API access is off) the player plays without saving,
-- so a failed load can never overwrite real data.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Saving = AnimeConfig.Saving

local PlayerData = {}

local LOAD_ATTEMPTS = 3
local sessions = {} -- [Player] = { Data = table, CanSave = boolean }

local store
do
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(Saving.DataStoreName)
	end)
	if not ok then
		warn("[TreasureGame] DataStore unavailable: " .. tostring(err))
	end
end

local function keyFor(player)
	return "u_" .. player.UserId
end

local function defaultData()
	return { Version = 1, Cash = AnimeConfig.Economy.StartingCash, Characters = {}, Chests = {} }
end

-- Drops entries the current config no longer knows about.
local function sanitize(data)
	local clean = defaultData()
	clean.Cash = type(data.Cash) == "number" and data.Cash or clean.Cash
	for _, entry in ipairs(type(data.Characters) == "table" and data.Characters or {}) do
		if type(entry) == "table" and AnimeConfig.GetCharacter(entry.CharacterId) then
			table.insert(clean.Characters, {
				Id = entry.Id or HttpService:GenerateGUID(false),
				CharacterId = entry.CharacterId,
				Location = entry.Location == "Plot" and "Plot" or "Inventory",
				Slot = entry.Slot,
				AcquiredAt = entry.AcquiredAt or os.time(),
			})
		end
	end
	for _, chest in ipairs(type(data.Chests) == "table" and data.Chests or {}) do
		if type(chest) == "table" and AnimeConfig.Bosses[chest.BossId] and AnimeConfig.Rarities[chest.Rarity] then
			table.insert(clean.Chests, {
				Id = chest.Id or HttpService:GenerateGUID(false),
				BossId = chest.BossId,
				Rarity = chest.Rarity,
				UnlockAt = type(chest.UnlockAt) == "number" and chest.UnlockAt or os.time(),
			})
		end
	end
	return clean
end

function PlayerData.NewId()
	return HttpService:GenerateGUID(false)
end

-- Yields. Returns the player's data table (kept in memory for the session).
function PlayerData.Load(player)
	local saved, ok, err = nil, false, "DataStore unavailable"
	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			ok, err = pcall(function()
				saved = store:GetAsync(keyFor(player))
			end)
			if ok then
				break
			end
			if attempt < LOAD_ATTEMPTS then
				task.wait(1)
			end
		end
	end
	if not ok then
		warn(("[TreasureGame] Could not load data for %s (%s). Playing this session without saving.")
			:format(player.Name, tostring(err)))
	end
	local data = type(saved) == "table" and sanitize(saved) or defaultData()
	sessions[player] = { Data = data, CanSave = ok }
	return data
end

function PlayerData.Get(player)
	local session = sessions[player]
	return session and session.Data
end

function PlayerData.CanSave(player)
	local session = sessions[player]
	return session ~= nil and session.CanSave
end

function PlayerData.Save(player)
	local session = sessions[player]
	if not session or not session.CanSave then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), session.Data)
	end)
	if not ok then
		warn(("[TreasureGame] Save failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

function PlayerData.Release(player)
	PlayerData.Save(player)
	sessions[player] = nil
end

function PlayerData.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(Saving.AutosaveSeconds)
			for player in pairs(sessions) do
				task.spawn(PlayerData.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(sessions) do
			pending += 1
			task.spawn(function()
				PlayerData.Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
