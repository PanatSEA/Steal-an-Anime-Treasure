-- AudioClient: the local player's own sounds (client only; ids and volumes in AudioConfig).
--   * UIClick: any GUI button you press (every GuiButton in PlayerGui, including ones added later)
--   * SafeZoneEnter: the moment you step into the SAFE ZONE (not while you stay in it, not on spawn)
--   * DesertAmbience (and any AudioConfig.Ambience loop): 2D, fades in while you stand over its
--     zone (Track_01, the desert TreasureField) and fades out when you leave
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeConfig = require(Shared:WaitForChild("AnimeConfig"))
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))

local World = AnimeConfig.World
local localPlayer = Players.LocalPlayer
local ZONE_CHECK_SECONDS = 0.25

-- UIClick -------------------------------------------------------------------------

local hooked = setmetatable({}, { __mode = "k" })
local function hookButton(instance)
	if instance:IsA("GuiButton") and not hooked[instance] then
		hooked[instance] = true
		instance.Activated:Connect(function()
			AudioConfig.Play("UIClick")
		end)
	end
end

local playerGui = localPlayer:WaitForChild("PlayerGui")
for _, descendant in ipairs(playerGui:GetDescendants()) do
	hookButton(descendant)
end
playerGui.DescendantAdded:Connect(hookButton)

-- Zones (SafeZoneEnter, ambience) ------------------------------------------------

-- Same test as the server's Zones module: inside the part's footprint, from its bottom up to
-- extraHeight above its top.
local function pointInPart(part, position, extraHeight)
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Z) <= half.Z
		and localPos.Y >= -half.Y
		and localPos.Y <= half.Y + (extraHeight or 0)
end

local function inSafeZone(position)
	local gameFolder = Workspace:FindFirstChild(World.GameFolderName)
	local folder = gameFolder and gameFolder:FindFirstChild(World.SafeZoneFolderName)
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			if part:IsA("BasePart") and pointInPart(part, position) then
				return true
			end
		end
	end
	return false
end

local function zonePart(path)
	local node = Workspace
	for _, name in ipairs(path) do
		node = node and node:FindFirstChild(name)
	end
	return node and node:IsA("BasePart") and node or nil
end

-- One looping 2D sound per ambience, faded in and out (the Sound stays, paused when silent).
local ambience = {} -- [key] = { Sound, On, Tween }
local function setAmbience(key, on)
	local entry = ambience[key]
	if not entry then
		local sound = AudioConfig.Play(key, nil, { Looped = true })
		if not sound then
			ambience[key] = { On = false }
			return
		end
		sound.Volume = 0
		sound:Pause()
		entry = { Sound = sound, On = false }
		ambience[key] = entry
	end
	if not entry.Sound or entry.On == on then
		return
	end
	entry.On = on
	local settings = AudioConfig.Ambience[key]
	local target = on and AudioConfig.Sounds[key].Volume or 0
	if entry.Tween then
		entry.Tween:Cancel()
	end
	if on and not entry.Sound.IsPlaying then
		entry.Sound:Resume()
	end
	entry.Tween = TweenService:Create(entry.Sound, TweenInfo.new(settings.FadeSeconds), { Volume = target })
	entry.Tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not entry.On then
			entry.Sound:Pause()
		end
	end)
	entry.Tween:Play()
end

local wasInSafeZone = nil -- nil until the first check, so spawning in the lobby doesn't play it
task.spawn(function()
	while true do
		task.wait(ZONE_CHECK_SECONDS)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local position = root.Position
			local safe = inSafeZone(position)
			if safe and wasInSafeZone == false then
				AudioConfig.Play("SafeZoneEnter")
			end
			wasInSafeZone = safe
			for key, settings in pairs(AudioConfig.Ambience) do
				local part = zonePart(settings.Zone)
				setAmbience(key, part ~= nil and pointInPart(part, position, settings.ExtraHeight))
			end
		else
			wasInSafeZone = nil -- respawning: don't count arriving at the spawn as entering
		end
	end
end)
