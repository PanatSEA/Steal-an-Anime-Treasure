-- Sfx: plays a one-shot sound, silently skipping placeholder ids from the spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))

local Sfx = {}

function Sfx.Play(soundId, parent)
	if AnimeConfig.IsPlaceholderAsset(soundId) or not parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 6)
end

return Sfx
