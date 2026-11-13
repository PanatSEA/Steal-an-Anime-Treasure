-- InventoryService: server side for the existing InventoryController UI (B to open).
-- Lists characters that did not fit on the plot. Storage only for now: equipping
-- and hotbar actions are refused with a message.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)

local InventoryService = {}

local HOTBAR_SLOTS = 10
local STORAGE_ONLY_MESSAGE = "Characters in the inventory are storage only for now"

local remotes = ReplicatedStorage:WaitForChild("Remote")

local function remoteEvent(name)
	local existing = remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end

local request = remoteEvent("InventoryRequest")
local updated = remoteEvent("InventoryUpdated")

local revisions = {}

-- Sends the full snapshot the client expects.
function InventoryService.Push(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	revisions[player] = (revisions[player] or 0) + 1
	local items = {}
	for _, entry in ipairs(data.Characters) do
		if entry.Location == "Inventory" then
			items[entry.Id] = { DefinitionId = entry.CharacterId, AcquiredAt = entry.AcquiredAt }
		end
	end
	updated:FireClient(player, {
		Items = items,
		Hotbar = {},
		EquippedItemId = nil,
		Revision = revisions[player],
		HotbarSlots = HOTBAR_SLOTS,
	})
end

function InventoryService.Forget(player)
	revisions[player] = nil
end

request.OnServerEvent:Connect(function(player, action)
	if action == "Sync" then
		InventoryService.Push(player)
	elseif action == "Equip" or action == "Assign" or action == "ClearSlot" then
		updated:FireClient(player, { Error = STORAGE_ONLY_MESSAGE })
	end
end)

return InventoryService
