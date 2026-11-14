-- TreasureServer: core loop.
-- Hit the dirt mound with the Pickaxe (DigService) -> on the final hit the server
-- rolls the chest rarity and the chest pops out and lands by the mound (boss still
-- asleep) -> anyone nearby holds E to pick it up; it goes on their head and the boss
-- wakes and chases with telegraphed skills (Boss TriggerCondition "OnChestPickedUp";
-- nobody picks it up in PickupTimeoutSeconds -> it sinks back and the mound
-- respawns) -> reach YOUR plot in the SAFE ZONE ->
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
local AudioConfig = require(ReplicatedStorage.Shared:WaitForChild("AudioConfig"))

-- Server-wide announcements (clients show them in chat and as a banner: Announcements).
local announce = Remotes.Event("Announce")
local ANNOUNCED_RARITIES = { Secret = "%s found a SECRET chest!" }

local World = AnimeConfig.World
local Dig = AnimeConfig.Dig
local PICKUP_SLACK = 4 -- studs of extra reach the server allows over PickupRange (lag)
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

-- `knockedOff` = the carrier lost it (hit by the boss, died): play ChestDrop where it was.
local function releaseTreasure(player, reason, knockedOff)
	local entry = carrying[player]
	if not entry then
		return
	end
	carrying[player] = nil
	player:SetAttribute("CarryingTreasure", nil)
	player:SetAttribute("CarryingRarity", nil)
	if entry.Part then
		if knockedOff then
			AudioConfig.Play("ChestDrop", entry.Part:GetPivot().Position) -- 3D, everyone nearby hears it
		end
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
		site.PendingRarity = nil -- a chest still waiting to be picked up goes back in the ground
		site.PickupToken = nil
		if site.PickupPrompt then
			site.PickupPrompt.Enabled = false
		end
		DigService.Reset(site.Model) -- a new mound with a buried chest
	end
end

local function aliveRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player.Parent == Players and humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- The player now carries this site's treasure (the boss chases carriers).
local function startCarrying(site, player, rarity)
	local entry = { Site = site, Part = nil, Rarity = rarity }
	carrying[player] = entry
	player:SetAttribute("CarryingTreasure", site.Config.BossId)
	player:SetAttribute("CarryingRarity", rarity)
	return entry
end

-- Puts the carried chest model on the player's head.
local function attachTreasure(player, entry)
	local treasure = Carry.MakeTreasure(entry.Site.Config, entry.Rarity, { Scale = AnimeConfig.Chest.CarryScale })
	if player.Character and Carry.AttachToCharacter(player.Character, treasure) then
		entry.Part = treasure
	else
		treasure:Destroy()
	end
end

-- "Pick up" (TriggerCondition OnChestPickedUp): the server checks the chest is still there, the
-- player is alive, close enough and not already carrying one. Anyone can take it, not only the
-- digger. The first completed hold wins; the boss wakes on the one who took it.
local function tryPickup(site, player)
	local rarity = site.PendingRarity
	if not rarity or carrying[player] then
		return
	end
	local root = aliveRoot(player)
	if not root or (root.Position - site.Anchor.Position).Magnitude > Dig.PickupRange + PICKUP_SLACK then
		return
	end
	site.PendingRarity = nil
	site.PickupToken = nil
	site.PickupPrompt.Enabled = false
	DigService.SetTaken(site.Model)
	attachTreasure(player, startCarrying(site, player, rarity))
	print(("[TreasureGame] %s picked up a %s %s — %s wakes up!"):format(player.Name, rarity, site.Config.TreasureName, site.Config.DisplayName))
	site.Boss:Wake(player)
end

local function makePickupPrompt(site)
	local cfg = site.Config
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = cfg.TreasureName
	prompt.KeyboardKeyCode = Enum.KeyCode[cfg.PickupKey or "E"] or Enum.KeyCode.E
	prompt.HoldDuration = cfg.PickupHoldSeconds or 1
	prompt.MaxActivationDistance = Dig.PickupRange
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = site.Anchor -- the dig site's invisible anchor, where the chest lands
	prompt.Triggered:Connect(function(player)
		tryPickup(site, player)
	end)
	return prompt
end

-- The server's final hit: roll the rarity. With OnChestPickedUp the chest lands by the mound and
-- waits (boss asleep) for someone to pick it up, or sinks back after PickupTimeoutSeconds. With
-- OnDigCompleted it goes straight onto the digger's head and the boss wakes.
local function completeDig(site, player)
	local cfg = site.Config
	local rarity = Roll.Rarity(cfg.RarityWeights)
	site.Available = false
	if ANNOUNCED_RARITIES[rarity] then
		-- The server decides and words it; clients only display it.
		announce:FireAllClients({ Rarity = rarity, Text = ANNOUNCED_RARITIES[rarity]:format(player.DisplayName), Sound = "SecretAnnounce" })
	end

	if cfg.TriggerCondition == "OnChestPickedUp" then
		print(("[TreasureGame] %s dug up a %s %s — waiting to be picked up"):format(player.Name, rarity, cfg.TreasureName))
		local token = {}
		site.PendingRarity = rarity
		site.PickupToken = token
		task.delay(Dig.EmergeSeconds, function() -- once every client has seen it land
			if site.PickupToken == token then
				site.PickupPrompt.Enabled = true
			end
		end)
		task.delay(Dig.PickupTimeoutSeconds, function()
			if site.PickupToken == token then
				print(("[TreasureGame] Nobody picked up the %s chest at %s; it sinks back"):format(rarity, site.Model.Name))
				setSiteAvailable(site, true) -- the chest sinks back, a new mound grows (DigClient)
			end
		end)
		return rarity
	end

	local entry = startCarrying(site, player, rarity)
	print(("[TreasureGame] %s dug up a %s %s — %s wakes up!"):format(player.Name, rarity, cfg.TreasureName, cfg.DisplayName))
	site.Boss:Wake(player)
	-- Let every client play the pop-out first, then put the chest on the digger's head.
	task.delay(Dig.EmergeSeconds, function()
		DigService.SetTaken(site.Model)
		if carrying[player] == entry then -- not dropped (hit, died or left) while it popped out
			attachTreasure(player, entry)
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
	-- PendingRarity: a dug-up chest waiting by the mound to be picked up (OnChestPickedUp)
	local site = { Model = model, Config = cfg, Available = false, Anchor = model:WaitForChild("DigMound") }

	DigService.Register(model, cfg, {
		CanDig = function(player)
			return site.Available and not carrying[player]
		end,
		OnComplete = function(player)
			return completeDig(site, player)
		end,
	})
	site.PickupPrompt = makePickupPrompt(site) -- after Register, which clears old prompts off the anchor

	site.Boss = BossController.new(model, cfg, {
		EffectsFolder = effectsFolder,
		IsCarrying = function(player)
			local entry = carrying[player]
			return entry ~= nil and entry.Site == site
		end,
		OnPlayerHit = function(player)
			local entry = carrying[player]
			if cfg.DropTreasureOnHit and entry and entry.Site == site then
				releaseTreasure(player, "dropped (hit by boss)", true)
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
		releaseTreasure(player, "dropped (died)", true)
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
