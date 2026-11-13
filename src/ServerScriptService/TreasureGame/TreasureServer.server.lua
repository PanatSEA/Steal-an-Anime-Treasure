-- TreasureServer: core loop.
-- Dig (hold E) -> server rolls the chest rarity -> carry it above your head ->
-- boss wakes and chases with telegraphed skills -> reach YOUR plot in the SAFE
-- ZONE -> it becomes a chest that unlocks, opens into a character and earns Cash
-- (PlotService). Cash, characters and chests are saved (PlayerData).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Zones = require(script.Parent.Zones)
local Carry = require(script.Parent.Carry)
local Sfx = require(script.Parent.Sfx)
local Roll = require(script.Parent.Roll)
local BossController = require(script.Parent.BossController)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local PlotService = require(script.Parent.PlotService)

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

-- [Player] = { Site = site, Part = BasePart, Rarity = string }
local carrying = {}

PlotService.Init()
PlotService.Start()
PlayerData.StartAutosave()

local function setSiteAvailable(site, available)
	site.Available = available
	site.Prompt.Enabled = available
	site.Display.Parent = available and site.Model or nil
end

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

local function setupSite(model)
	local bossId = model:GetAttribute("BossId")
	if not bossId then
		warn(("[TreasureGame] Dig site %s has no BossId attribute"):format(model:GetFullName()))
		return
	end
	local cfg = AnimeConfig.GetBoss(bossId)
	local mound = model:WaitForChild("DigMound")

	local prompt = mound:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Dig"
	prompt.ObjectText = cfg.TreasureName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = cfg.DigTimeSeconds
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = mound

	-- The mound shows a neutral treasure; the rarity is only rolled when a dig completes.
	local display = Carry.MakeTreasure(cfg)
	display.Anchored = true
	display.CFrame = mound.CFrame * CFrame.new(0, mound.Size.Y / 2 + display.Size.Y / 2 + 0.2, 0)
	display:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel").Text = cfg.TreasureName

	local site = { Model = model, Config = cfg, Prompt = prompt, Display = display, Available = false }

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

	prompt.Triggered:Connect(function(player)
		if not site.Available or carrying[player] then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local rarity = Roll.Rarity(cfg.RarityWeights) -- server-side roll at dig time
		local treasure = Carry.MakeTreasure(cfg, rarity)
		if not Carry.AttachToCharacter(character, treasure) then
			treasure:Destroy()
			return
		end
		setSiteAvailable(site, false)
		carrying[player] = { Site = site, Part = treasure, Rarity = rarity }
		player:SetAttribute("CarryingTreasure", cfg.BossId)
		player:SetAttribute("CarryingRarity", rarity)
		Sfx.Play(cfg.DigSoundId, mound)
		print(("[TreasureGame] %s dug a %s %s — %s wakes up!"):format(player.Name, rarity, cfg.TreasureName, cfg.DisplayName))
		site.Boss:Wake(player)
	end)
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
		for player, _ in pairs(carrying) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local plotPart = root and Zones.FindPlotAt(root.Position)
			if plotPart and PlotService.IsOwnPlot(player, plotPart) then
				deliver(player)
			end
		end
		task.wait(DELIVERY_TICK)
	end
end)
