-- PlotService: plot ownership, banked treasure slots, income and selling (Phase 3).
-- Session only: a player's plot, banked treasures and Cash reset when they leave.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Carry = require(script.Parent.Carry)

local World = AnimeConfig.World
local Economy = AnimeConfig.Economy

local OWNER_ONLY_TAG = "OwnerOnlyPrompt" -- client hides these prompts from non-owners
local SLOT_COLUMNS = 4
local SLOT_SPACING = Vector2.new(10, 20)
local FLASH_SECONDS = 2

local PlotService = {}

local plots = {} -- ordered { Folder, Part, Owner, Slots = {}, Sign, FlashToken }
local plotByPlayer = {}

local function setStat(player, name, value)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(name)
	if stat then
		stat.Value = value
	end
end

local function addCash(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value += amount
	end
end

local function countSlots(plot)
	local count = 0
	for i = 1, Economy.PlotSlots do
		if plot.Slots[i] then
			count += 1
		end
	end
	return count
end

local function refreshSign(plot)
	if plot.Owner then
		plot.Sign.Text = ("%s's Plot  %d/%d"):format(plot.Owner.DisplayName, countSlots(plot), Economy.PlotSlots)
		setStat(plot.Owner, "Treasures", countSlots(plot))
	else
		plot.Sign.Text = "Free Plot"
	end
end

local function flashSign(plot, text)
	local token = {}
	plot.FlashToken = token
	plot.Sign.Text = text
	task.delay(FLASH_SECONDS, function()
		if plot.FlashToken == token then
			plot.FlashToken = nil
			refreshSign(plot)
		end
	end)
end

local function slotOffset(index)
	local rows = math.ceil(Economy.PlotSlots / SLOT_COLUMNS)
	local col = (index - 1) % SLOT_COLUMNS
	local row = math.floor((index - 1) / SLOT_COLUMNS)
	local x = (col - (SLOT_COLUMNS - 1) / 2) * SLOT_SPACING.X
	local z = (row - (rows - 1) / 2) * SLOT_SPACING.Y
	return x, z
end

local function makeSign(part)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlotSign"
	billboard.Size = UDim2.fromOffset(280, 44)
	billboard.StudsOffset = Vector3.new(0, 9, 0)
	billboard.MaxDistance = 200
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
		local plot = { Folder = folder, Part = part, Owner = nil, Slots = {}, Sign = makeSign(part) }
		table.insert(plots, plot)
		refreshSign(plot)
	end
end

function PlotService.Assign(player)
	if plotByPlayer[player] then
		return plotByPlayer[player]
	end
	for _, plot in ipairs(plots) do
		if not plot.Owner then
			plot.Owner = player
			plot.Folder:SetAttribute("OwnerUserId", player.UserId)
			plotByPlayer[player] = plot
			refreshSign(plot)
			return plot
		end
	end
	warn(("[TreasureGame] No free plot for %s (all %d taken)"):format(player.Name, #plots))
	return nil
end

function PlotService.Release(player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	for i = 1, Economy.PlotSlots do
		local slot = plot.Slots[i]
		if slot then
			slot.Part:Destroy()
			plot.Slots[i] = nil
		end
	end
	plot.Owner = nil
	plot.FlashToken = nil
	plot.Folder:SetAttribute("OwnerUserId", nil)
	refreshSign(plot)
end

function PlotService.IsOwnPlot(player, plotPart)
	local plot = plotByPlayer[player]
	return plot ~= nil and plot.Part == plotPart
end

local function sell(player, plot, index)
	local slot = plot.Slots[index]
	if not slot or plot.Owner ~= player then
		return
	end
	plot.Slots[index] = nil
	slot.Part:Destroy()
	addCash(player, slot.Config.SellPrice)
	refreshSign(plot)
	print(("[TreasureGame] %s sold %s for %d"):format(player.Name, slot.Config.TreasureName, slot.Config.SellPrice))
end

-- Puts a treasure into the player's first free slot. Returns false if the plot is full.
function PlotService.TryBank(player, cfg)
	local plot = plotByPlayer[player]
	if not plot then
		return false
	end
	local index
	for i = 1, Economy.PlotSlots do
		if not plot.Slots[i] then
			index = i
			break
		end
	end
	if not index then
		if not plot.FlashToken then
			flashSign(plot, "Plot full! Sell a treasure")
		end
		return false
	end

	local display = Carry.MakeTreasure(cfg)
	display.Anchored = true
	local x, z = slotOffset(index)
	display.CFrame = plot.Part.CFrame
		* CFrame.new(x, plot.Part.Size.Y / 2 + display.Size.Y / 2 + 0.2, z)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = ("Sell for %d"):format(cfg.SellPrice)
	prompt.ObjectText = cfg.TreasureName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Economy.SellHoldSeconds
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(prompt, OWNER_ONLY_TAG)
	prompt.Parent = display

	prompt.Triggered:Connect(function(triggeredBy)
		if triggeredBy == player then
			sell(player, plot, index)
		end
	end)

	display.Parent = plot.Folder
	plot.Slots[index] = { Config = cfg, Part = display }
	refreshSign(plot)
	return true
end

-- Pays IncomePerSecond for every banked treasure, forever.
function PlotService.StartIncome()
	task.spawn(function()
		while true do
			task.wait(Economy.IncomeTickSeconds)
			for player, plot in pairs(plotByPlayer) do
				local total = 0
				for i = 1, Economy.PlotSlots do
					local slot = plot.Slots[i]
					if slot then
						total += slot.Config.IncomePerSecond * Economy.IncomeTickSeconds
					end
				end
				if total > 0 and player.Parent == Players then
					addCash(player, total)
				end
			end
		end
	end)
end

return PlotService
