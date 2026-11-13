-- TreasureServer: Phase 1 core loop.
-- Dig (hold E) -> carry treasure above head -> boss wakes and chases with
-- telegraphed skills -> reach your base plot in the SAFE ZONE to bank it.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Zones = require(script.Parent.Zones)
local Carry = require(script.Parent.Carry)
local Sfx = require(script.Parent.Sfx)
local BossController = require(script.Parent.BossController)

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

-- [Player] = { Site = site, Part = BasePart }
local carrying = {}

local function getTreasureStat(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Treasures")
end

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
	if entry.Part then
		entry.Part:Destroy()
	end
	print(("[TreasureGame] %s %s: %s"):format(player.Name, reason, entry.Site.Config.TreasureName))
end

local function deliver(player)
	releaseTreasure(player, "banked")
	local stat = getTreasureStat(player)
	if stat then
		stat.Value += 1
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

	local display = Carry.MakeTreasure(cfg)
	display.Anchored = true
	display.CFrame = mound.CFrame * CFrame.new(0, mound.Size.Y / 2 + display.Size.Y / 2 + 0.2, 0)

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

		local treasure = Carry.MakeTreasure(cfg)
		if not Carry.AttachToCharacter(character, treasure) then
			treasure:Destroy()
			return
		end
		setSiteAvailable(site, false)
		carrying[player] = { Site = site, Part = treasure }
		player:SetAttribute("CarryingTreasure", cfg.BossId)
		Sfx.Play(cfg.DigSoundId, mound)
		print(("[TreasureGame] %s dug %s — %s wakes up!"):format(player.Name, cfg.TreasureName, cfg.DisplayName))
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

local function onPlayerAdded(player)
	if not player:FindFirstChild("leaderstats") then
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	if not getTreasureStat(player) then
		local stat = Instance.new("IntValue")
		stat.Name = "Treasures"
		stat.Parent = player.leaderstats
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		releaseTreasure(player, "dropped (respawned)")
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	releaseTreasure(player, "dropped (left)")
end)

-- Phase 1: any base plot banks the treasure (plot ownership comes later).
task.spawn(function()
	while true do
		for player, _ in pairs(carrying) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and Zones.FindPlotAt(root.Position) then
				deliver(player)
			end
		end
		task.wait(DELIVERY_TICK)
	end
end)
