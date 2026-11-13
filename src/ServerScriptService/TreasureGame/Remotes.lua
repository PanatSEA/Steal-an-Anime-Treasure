-- Remotes: RemoteEvents in ReplicatedStorage.Remote, created on first use.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("Remote")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remote"
	folder.Parent = ReplicatedStorage
end

function Remotes.Event(name)
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

return Remotes
