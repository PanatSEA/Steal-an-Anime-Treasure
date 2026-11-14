-- TreasureServer: core loop.
-- Hit the dirt mound with the Pickaxe (DigService) -> on the final hit the server
-- rolls the chest rarity, the chest pops out and lands on your head -> the boss
-- wakes and chases with telegraphed skills -> reach YOUR plot in the SAFE ZONE ->
-- it becomes a chest that unlocks, opens into a character and earns Cash
-- (PlotService). Cash, characters and chests are saved (PlayerData).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Zones = require(script.Parent.Zones)
local Carry = require(script.Parent.Carry)
local Roll = require(script.Parent.Roll)
local BossController = require(script.Parent.BossController)
local DigService = require(script.Parent.DigService)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(script.Parent.Remotes)

-- Server-wide announcements (clients show them in chat and as a banner: Announcements).
local announce = Remotes.Event("Announce")
local ANNOUNCED_RARITIES = { Secret = "%s found a SECRET chest!" }

local World = AnimeConfig.World
local gameFolder = Workspace:WaitForChild(World.GameFolderName)
local digSitesFolder = gameFolder:WaitForChild(World.DigSitesFolderName)

local effectsFolder = gameFolder:FindFirstChild(World.EffectsFolderName)
if not effectsFolder then
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = World.EffectsFolderName
	effectsFolder.Parent = gameFolder
end

local DELIVERY_TICK = 0.2

-- [Player] = { Site = site, Part = Model?, Rarity = string }
-- Part is nil while the chest is still popping out of the ground.
local carrying = {}

PlotService.Init()
PlotService.Start()
PlayerData.StartAutosave()

local function releaseTreasure(player, reason)
	local entry = carrying[player]
	if not entry then
		return
	end
	carrying[player] = nil
	player:SetAttribute("CarryingTreasure", nil)
	player:SetAttribute("CarryingRarity", nil)
	if entry.Part then
		entry.Part:Destroy()
	end
	print(("[TreasureGame] %s %s: %s [%s]"):format(player.Name, reason, entry.Site.Config.TreasureName, entry.Rarity))
end

local function deliver(player)
	local entry = carrying[player]
	if entry and PlotService.AddChest(player, entry.Site.Config.BossId, entry.Rarity) then
		releaseTreasure(player, "banked")
	end
end

local function setSiteAvailable(site, available)
	site.Available = available
	if available then
		DigService.Reset(site.Model) -- a new mound with a buried chest
	end
end

-- The server's final hit: roll the rarity, wake the boss, then lift the chest onto the digger.
local function completeDig(site, player)
	local cfg = site.Config
	local rarity = Roll.Rarity(cfg.RarityWeights)
	site.Available = false

	local entry = { Site = site, Part = nil, Rarity = rarity }
	carrying[player] = entry
	player:SetAttribute("CarryingTreasure", cfg.BossId)
	player:SetAttribute("CarryingRarity", rarity)
	print(("[TreasureGame] %s dug up a %s %s — %s wakes up!"):format(player.Name, rarity, cfg.TreasureName, cfg.DisplayName))
	if ANNOUNCED_RARITIES[rarity] then
		-- The server decides and words it; clients only display it.
		announce:FireAllClients({ Rarity = rarity, Text = ANNOUNCED_RARITIES[rarity]:format(player.DisplayName) })
	end
	site.Boss:Wake(player)

	-- Let every client play the pop-out first, then put the chest on the digger's head.
	task.delay(AnimeConfig.Dig.EmergeSeconds, function()
		DigService.SetTaken(site.Model)
		if carrying[player] ~= entry then
			return -- dropped (hit, died or left) while the chest was popping out
		end
		local treasure = Carry.MakeTreasure(cfg, rarity, { Scale = AnimeConfig.Chest.CarryScale })
		if player.Character and Carry.AttachToCharacter(player.Character, treasure) then
			entry.Part = treasure
		else
			treasure:Destroy()
		end
	end)
	return rarity
end

local function setupSite(model)
	local bossId = model:GetAttribute("BossId")
	if not bossId then
		warn(("[TreasureGame] Dig site %s has no BossId attribute"):format(model:GetFullName()))
		return
	end
	local cfg = AnimeConfig.GetBoss(bossId)
	local site = { Model = model, Config = cfg, Available = false }

	DigService.Register(model, cfg, {
		CanDig = function(player)
			return site.Available and not carrying[player]
		end,
		OnComplete = function(player)
			return completeDig(site, player)
		end,
	})

	site.Boss = BossController.new(model, cfg, {
		EffectsFolder = effectsFolder,
		IsCarrying = function(player)
			local entry = carrying[player]
			return entry ~= nil and entry.Site == site
		end,
		OnPlayerHit = function(player)
			local entry = carrying[player]
			if cfg.DropTreasureOnHit and entry and entry.Site == site then
				releaseTreasure(player, "dropped (hit by boss)")
			end
		end,
		OnSleep = function()
			setSiteAvailable(site, true)
		end,
	})
end

for _, model in ipairs(digSitesFolder:GetChildren()) do
	task.spawn(setupSite, model)
end
digSitesFolder.ChildAdded:Connect(setupSite)

-- Players
local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		releaseTreasure(player, "dropped (died)")
	end)
end

local function addStat(leaderstats, name, value)
	local stat = leaderstats:FindFirstChild(name)
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = leaderstats
	end
	stat.Value = value
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		releaseTreasure(player, "dropped (respawned)")
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	InventoryService.Track(player)

	local data = PlayerData.Load(player) -- yields
	if player.Parent ~= Players then
		PlayerData.Release(player)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	addStat(leaderstats, "Cash", data.Cash)
	addStat(leaderstats, "Characters", #data.Characters)

	PlotService.Assign(player)
	InventoryService.Push(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	releaseTreasure(player, "dropped (left)")
	PlotService.Release(player)
	InventoryService.Forget(player)
	PlayerData.Release(player)
end)

-- Only your own plot accepts the treasure.
task.spawn(function()
	while true do
		for player, entry in pairs(carrying) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local plotPart = entry.Part and root and Zones.FindPlotAt(root.Position)
			if plotPart and PlotService.IsOwnPlot(player, plotPart) then
				deliver(player)
			end
		end
		task.wait(DELIVERY_TICK)
	end
end)
