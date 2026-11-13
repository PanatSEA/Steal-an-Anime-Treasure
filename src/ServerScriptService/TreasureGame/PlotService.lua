-- PlotService: plot ownership, chests and characters on plots, income (Phase 3b).
--   * Each player gets the first free plot on join.
--   * Banked treasure becomes a chest of its rolled rarity. It unlocks after
--     UnlockTimeSeconds (counted from os.time(), so it keeps counting offline),
--     then the owner holds E for OpenTimeSeconds to open it.
--   * Opening picks a character of that rarity (server roll). Up to
--     PlotCharacterSlots stand on the plot and earn income; the rest go to the
--     inventory (storage only).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Carry = require(script.Parent.Carry)
local ModelLoader = require(script.Parent.ModelLoader)
local Roll = require(script.Parent.Roll)
local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)
local Remotes = require(script.Parent.Remotes)

local World = AnimeConfig.World
local Economy = AnimeConfig.Economy
local ChestConfig = AnimeConfig.Chest

local treasureFx = Remotes.Event("TreasureFx") -- clients play the lid-opening + coin-pop animation

local OWNER_ONLY_TAG = "OwnerOnlyPrompt" -- client shows these only to the owner (and only when Ready)
local TIMER_TICK = 0.5

-- Plot layout in the plot's local space (plot is 47 x 54 studs).
local CHARACTER_COLUMNS = 4
local CHARACTER_SPACING = Vector2.new(10, 10)
local CHARACTER_ROW_Z = -18 -- first character row, back half of the plot
local CHEST_COLUMNS = 5
local CHEST_ROWS_PER_LAYER = 3
local CHEST_SPACING = Vector2.new(8, 7)
local CHEST_ROW_Z = 6 -- first chest row, front half of the plot
local CHEST_LAYER_HEIGHT = 2.2

local PlotService = {}

local plots = {} -- ordered { Folder, Part, Owner, Sign, Chests = {[id] = view}, Characters = {[id] = model} }
local plotByPlayer = {}

-- Helpers ------------------------------------------------------------------

local function setStat(player, name, value)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	if stat then
		stat.Value = value
	end
end

local function plotTop(plot)
	return plot.Part.Size.Y / 2
end

local function countPlotCharacters(data)
	local count = 0
	for _, entry in ipairs(data.Characters) do
		if entry.Location == "Plot" then
			count += 1
		end
	end
	return count
end

local function freePlotSlot(data)
	local used = {}
	for _, entry in ipairs(data.Characters) do
		if entry.Location == "Plot" and entry.Slot then
			used[entry.Slot] = true
		end
	end
	for slot = 1, Economy.PlotCharacterSlots do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function refresh(plot)
	local player = plot.Owner
	if not player then
		plot.Sign.Text = "Free Plot"
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	plot.Sign.Text = ("%s's Plot  %d/%d  |  %d chest%s"):format(
		player.DisplayName,
		countPlotCharacters(data),
		Economy.PlotCharacterSlots,
		#data.Chests,
		#data.Chests == 1 and "" or "s"
	)
	setStat(player, "Characters", #data.Characters)
	setStat(player, "Cash", data.Cash)
end

local function makeSign(part)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlotSign"
	billboard.Size = UDim2.fromOffset(320, 44)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.MaxDistance = 220
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	return label
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- Characters ----------------------------------------------------------------

local function characterCFrame(plot, slot)
	local col = (slot - 1) % CHARACTER_COLUMNS
	local row = (slot - 1) // CHARACTER_COLUMNS
	local x = (col - (CHARACTER_COLUMNS - 1) / 2) * CHARACTER_SPACING.X
	local z = CHARACTER_ROW_Z + row * CHARACTER_SPACING.Y
	return plot.Part.CFrame * CFrame.new(x, plotTop(plot), z)
end

local function addCharacterLabel(model, entry)
	local anchor = model:FindFirstChild("Head") or model.PrimaryPart
	local rarity = AnimeConfig.Rarities[entry.Rarity]
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CharacterLabel"
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 80
	billboard.Parent = anchor

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = rarity.Color
	name.TextStrokeTransparency = 0.2
	name.Text = ("%s [%s]"):format(AnimeConfig.GetCharacterName(entry), entry.Rarity)
	name.Parent = billboard

	local income = Instance.new("TextLabel")
	income.Size = UDim2.fromScale(1, 0.45)
	income.Position = UDim2.fromScale(0, 0.55)
	income.BackgroundTransparency = 1
	income.Font = Enum.Font.GothamBold
	income.TextScaled = true
	income.TextColor3 = Color3.fromRGB(120, 255, 140)
	income.TextStrokeTransparency = 0.2
	income.Text = ("+%d Cash/s"):format(entry.IncomePerSecond)
	income.Parent = billboard
end

local function spawnCharacter(plot, owned)
	local entry, seriesId = AnimeConfig.GetCharacter(owned.CharacterId)
	local model = ModelLoader.Character(seriesId, entry.CharacterId)
	addCharacterLabel(model, entry)

	-- Stand the model on the plot: pivot to the slot, then lift so its bottom touches the top.
	model:PivotTo(characterCFrame(plot, owned.Slot))
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	local target = (plot.Part.CFrame * CFrame.new(0, plotTop(plot), 0)).Position.Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, target - bottom, 0))

	model.Parent = plot.Folder
	plot.Characters[owned.Id] = model
end

-- Chests --------------------------------------------------------------------

local function chestCFrame(plot, index, model)
	local perLayer = CHEST_COLUMNS * CHEST_ROWS_PER_LAYER
	local layer = (index - 1) // perLayer
	local inLayer = (index - 1) % perLayer
	local col = inLayer % CHEST_COLUMNS
	local row = inLayer // CHEST_COLUMNS
	local x = (col - (CHEST_COLUMNS - 1) / 2) * CHEST_SPACING.X
	local z = CHEST_ROW_Z + row * CHEST_SPACING.Y
	local y = plotTop(plot) + model.PrimaryPart.Size.Y / 2 + 0.05 + layer * CHEST_LAYER_HEIGHT
	return plot.Part.CFrame * CFrame.new(x, y, z)
end

local function layoutChests(plot, data)
	for index, chest in ipairs(data.Chests) do
		local view = plot.Chests[chest.Id]
		if view then
			view.Model:PivotTo(chestCFrame(plot, index, view.Model))
		end
	end
end

local openChest -- forward declaration

local function spawnChest(plot, player, chest)
	local boss = AnimeConfig.GetBoss(chest.BossId)
	local model = Carry.MakeTreasure(boss, chest.Rarity, { Scale = ChestConfig.PlotScale, Anchored = true })
	model.Name = "Chest_" .. chest.Rarity
	local label = Carry.GetLabel(model)
	label.Parent.Size = UDim2.fromOffset(200, 40)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = chest.Rarity .. " Chest"
	prompt.KeyboardKeyCode = Enum.KeyCode[boss.OpenKey] or Enum.KeyCode.E
	prompt.HoldDuration = boss.OpenTimeSeconds
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt:SetAttribute("Ready", false)
	CollectionService:AddTag(prompt, OWNER_ONLY_TAG)
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(triggeredBy)
		if triggeredBy == player then
			openChest(player, chest.Id)
		end
	end)

	model.Parent = plot.Folder
	plot.Chests[chest.Id] = { Model = model, Label = label, Prompt = prompt, Chest = chest }
end

local function updateChestTimers(plot)
	local now = os.time()
	for _, view in pairs(plot.Chests) do
		if view.Opening then
			continue
		end
		local remaining = view.Chest.UnlockAt - now
		local ready = remaining <= 0
		view.Label.Text = ready
			and ("%s Chest\nReady! Hold %s"):format(view.Chest.Rarity, AnimeConfig.GetBoss(view.Chest.BossId).OpenKey)
			or ("%s Chest\n%s"):format(view.Chest.Rarity, formatTime(remaining))
		if view.Prompt:GetAttribute("Ready") ~= ready then
			view.Prompt:SetAttribute("Ready", ready)
		end
	end
end

openChest = function(player, chestId)
	local plot = plotByPlayer[player]
	local data = PlayerData.Get(player)
	if not plot or not data then
		return
	end
	local index, chest
	for i, candidate in ipairs(data.Chests) do
		if candidate.Id == chestId then
			index, chest = i, candidate
			break
		end
	end
	if not chest or os.time() < chest.UnlockAt then
		return -- unknown chest or still locked: the server decides, not the client
	end
	local view = plot.Chests[chestId]
	if view and view.Opening then
		return
	end

	-- Commit the result to the player's data first, so leaving mid-animation loses nothing.
	table.remove(data.Chests, index)
	local boss = AnimeConfig.GetBoss(chest.BossId)
	local picked = Roll.Character(boss.OpensInto, chest.Rarity)
	local slot = freePlotSlot(data)
	local owned = {
		Id = PlayerData.NewId(),
		CharacterId = picked.CharacterId,
		Location = slot and "Plot" or "Inventory",
		Slot = slot,
		AcquiredAt = os.time(),
	}
	table.insert(data.Characters, owned)
	refresh(plot)

	if view then
		view.Opening = true
		view.Prompt:SetAttribute("Ready", false)
		view.Label.Text = ("%s Chest\nOpening..."):format(chest.Rarity)
		treasureFx:FireAllClients("ChestOpen", view.Model)
		task.wait(ChestConfig.OpenAnimationSeconds)
		view.Model:Destroy()
		plot.Chests[chestId] = nil
	end
	if plotByPlayer[player] ~= plot then
		return -- they left during the animation; their data already has the character
	end

	if slot then
		spawnCharacter(plot, owned)
	else
		InventoryService.Push(player)
	end
	layoutChests(plot, data)
	refresh(plot)
	print(("[TreasureGame] %s opened a %s chest: %s -> %s"):format(
		player.Name, chest.Rarity, picked.CharacterId, owned.Location))
end

-- Public API ------------------------------------------------------------------

local function plotNumber(folder)
	return tonumber(folder.Name:match("%d+")) or math.huge
end

-- Finds every plot under World.PlotsPath once, in Place1..PlaceN order.
function PlotService.Init()
	local node = Workspace
	for _, name in ipairs(World.PlotsPath) do
		node = node and node:WaitForChild(name)
	end
	local folders = {}
	for _, folder in ipairs(node:GetChildren()) do
		local part = folder:FindFirstChild(World.PlotPartName)
		if part and part:IsA("BasePart") then
			table.insert(folders, folder)
		end
	end
	table.sort(folders, function(a, b)
		return plotNumber(a) < plotNumber(b)
	end)
	for _, folder in ipairs(folders) do
		local part = folder[World.PlotPartName]
		local old = part:FindFirstChild("PlotSign")
		if old then
			old:Destroy()
		end
		local plot = { Folder = folder, Part = part, Owner = nil, Sign = makeSign(part), Chests = {}, Characters = {} }
		table.insert(plots, plot)
		refresh(plot)
	end
end

-- Gives the player a plot and builds it from their loaded data.
function PlotService.Assign(player)
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	local data = PlayerData.Get(player)
	local plot
	for _, candidate in ipairs(plots) do
		if not candidate.Owner then
			plot = candidate
			break
		end
	end
	if not plot or not data then
		warn(("[TreasureGame] No free plot for %s (all %d taken)"):format(player.Name, #plots))
		return nil
	end
	plot.Owner = player
	plot.Folder:SetAttribute("OwnerUserId", player.UserId)
	plotByPlayer[player] = plot

	-- Plot characters need a unique slot within range. Pass 1 keeps valid slots,
	-- pass 2 re-slots the rest, and anything that still doesn't fit goes to the inventory.
	local taken, needsSlot = {}, {}
	for _, owned in ipairs(data.Characters) do
		if owned.Location == "Plot" then
			local slot = owned.Slot
			if type(slot) == "number" and slot >= 1 and slot <= Economy.PlotCharacterSlots and not taken[slot] then
				taken[slot] = true
			else
				table.insert(needsSlot, owned)
			end
		end
	end
	for _, owned in ipairs(needsSlot) do
		local free
		for slot = 1, Economy.PlotCharacterSlots do
			if not taken[slot] then
				free = slot
				break
			end
		end
		if free then
			owned.Slot = free
			taken[free] = true
		else
			owned.Location = "Inventory"
			owned.Slot = nil
		end
	end
	for _, owned in ipairs(data.Characters) do
		if owned.Location == "Plot" then
			spawnCharacter(plot, owned)
		end
	end
	for _, chest in ipairs(data.Chests) do
		spawnChest(plot, player, chest)
	end
	layoutChests(plot, data)
	updateChestTimers(plot)
	refresh(plot)
	return plot
end

function PlotService.Release(player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	for id, view in pairs(plot.Chests) do
		view.Model:Destroy()
		plot.Chests[id] = nil
	end
	for id, model in pairs(plot.Characters) do
		model:Destroy()
		plot.Characters[id] = nil
	end
	plot.Owner = nil
	plot.Folder:SetAttribute("OwnerUserId", nil)
	refresh(plot)
end

function PlotService.IsOwnPlot(player, plotPart)
	local plot = plotByPlayer[player]
	return plot ~= nil and plot.Part == plotPart
end

-- Turns a banked treasure into a chest of the rarity rolled at dig time.
function PlotService.AddChest(player, bossId, rarity)
	local plot = plotByPlayer[player]
	local data = PlayerData.Get(player)
	if not plot or not data then
		return false
	end
	local boss = AnimeConfig.GetBoss(bossId)
	local unlockSeconds = AnimeConfig.GetSeries(boss.OpensInto).UnlockTimeSeconds[rarity]
	local chest = { Id = PlayerData.NewId(), BossId = bossId, Rarity = rarity, UnlockAt = os.time() + unlockSeconds }
	table.insert(data.Chests, chest)
	spawnChest(plot, player, chest)
	layoutChests(plot, data)
	updateChestTimers(plot)
	refresh(plot)
	return true
end

-- Chest countdowns and income.
function PlotService.Start()
	task.spawn(function()
		while true do
			task.wait(TIMER_TICK)
			for _, plot in pairs(plotByPlayer) do
				updateChestTimers(plot)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Economy.IncomeTickSeconds)
			for player, plot in pairs(plotByPlayer) do
				local data = PlayerData.Get(player)
				if data and player.Parent == Players then
					local total = 0
					for _, owned in ipairs(data.Characters) do
						if owned.Location == "Plot" then
							local entry = AnimeConfig.GetCharacter(owned.CharacterId)
							total += entry.IncomePerSecond * Economy.IncomeTickSeconds
						end
					end
					if total > 0 then
						data.Cash += total
						setStat(player, "Cash", data.Cash)
					end
				end
			end
		end
	end)
end

return PlotService
