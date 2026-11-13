-- InventoryService: server side for the existing InventoryController UI (B to open).
--   * Lists characters that didn't fit on the plot (storage only).
--   * Shows the Pickaxe Tool in hotbar slot 1: press 1 (or click the slot) to equip / put away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local InventoryService = {}

local HOTBAR_SLOTS = 10
local PICKAXE_ITEM_ID = "tool_pickaxe"
local PICKAXE_DEFINITION_ID = "Tool_Pickaxe" -- defined in CharacterItemDefinitions
local PICKAXE_SLOT = "1"
local MESSAGES = {
	StorageOnly = "Characters in the inventory are storage only for now",
	PickaxeSlot = "The Pickaxe stays in slot 1",
	NoPickaxe = "No Pickaxe right now",
}

local request = Remotes.Event("InventoryRequest")
local updated = Remotes.Event("InventoryUpdated")

local revisions = {}
local pushQueued = {}

-- Returns the player's Pickaxe Tool and whether it's equipped.
local function findPickaxe(player)
	local name = AnimeConfig.Dig.ToolName
	local equipped = player.Character and player.Character:FindFirstChild(name)
	if equipped and equipped:IsA("Tool") then
		return equipped, true
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local stored = backpack and backpack:FindFirstChild(name)
	if stored and stored:IsA("Tool") then
		return stored, false
	end
	return nil, false
end

-- Sends the full snapshot the client expects.
function InventoryService.Push(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	revisions[player] = (revisions[player] or 0) + 1
	local items, hotbar, equippedId = {}, {}, nil
	for _, entry in ipairs(data.Characters) do
		if entry.Location == "Inventory" then
			items[entry.Id] = { DefinitionId = entry.CharacterId, AcquiredAt = entry.AcquiredAt }
		end
	end
	local pickaxe, equipped = findPickaxe(player)
	if pickaxe then
		items[PICKAXE_ITEM_ID] = { DefinitionId = PICKAXE_DEFINITION_ID, AcquiredAt = 0 }
		hotbar[PICKAXE_SLOT] = PICKAXE_ITEM_ID
		if equipped then
			equippedId = PICKAXE_ITEM_ID
		end
	end
	updated:FireClient(player, {
		Items = items,
		Hotbar = hotbar,
		EquippedItemId = equippedId,
		Revision = revisions[player],
		HotbarSlots = HOTBAR_SLOTS,
	})
end

local function queuePush(player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		if player.Parent then
			InventoryService.Push(player)
		end
	end)
end

local function togglePickaxe(player)
	local tool, equipped = findPickaxe(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not tool or not humanoid or humanoid.Health <= 0 then
		updated:FireClient(player, { Error = MESSAGES.NoPickaxe })
		return
	end
	if equipped then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

local function watch(player, container)
	local function changed(child)
		if child.Name == AnimeConfig.Dig.ToolName then
			if child:IsA("Tool") and child.CanBeDropped then
				child.CanBeDropped = false -- keep it from being dropped and lost
			end
			queuePush(player)
		end
	end
	for _, child in ipairs(container:GetChildren()) do
		changed(child)
	end
	container.ChildAdded:Connect(changed)
	container.ChildRemoved:Connect(changed)
end

-- Keeps the hotbar in sync as the Pickaxe moves between Backpack and character.
function InventoryService.Track(player)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(player, child)
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(player, backpack)
	end
	player.CharacterAdded:Connect(function(character)
		watch(player, character)
	end)
	if player.Character then
		watch(player, player.Character)
	end
end

function InventoryService.Forget(player)
	revisions[player] = nil
	pushQueued[player] = nil
end

request.OnServerEvent:Connect(function(player, action, itemId)
	if action == "Sync" then
		InventoryService.Push(player)
	elseif action == "Equip" then
		if itemId == PICKAXE_ITEM_ID then
			togglePickaxe(player)
		else
			updated:FireClient(player, { Error = MESSAGES.StorageOnly })
		end
	elseif action == "Assign" then
		updated:FireClient(player, { Error = itemId == PICKAXE_ITEM_ID and MESSAGES.PickaxeSlot or MESSAGES.StorageOnly })
	elseif action == "ClearSlot" then
		updated:FireClient(player, { Error = MESSAGES.PickaxeSlot })
	end
end)

return InventoryService
