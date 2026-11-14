-- Announcements: server-wide messages (client, display only). The server decides and words them
-- (TreasureServer fires Remote.Announce, e.g. "[Player] found a SECRET chest!"); this shows each
-- one in the chat as a system message and as a banner at the top of the screen, in the rarity's
-- colour (ChestFxPresets.RarityFx[rarity].Announce.Color; red for Secret).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local ChestFxPresets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ChestFxPresets"))
local announce = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Announce")

local BANNER_SECONDS = 4 -- on screen, including the fades
local FADE_SECONDS = 0.35
local DEFAULT_COLOR = Color3.new(1, 1, 1)

local function escapeRichText(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function showInChat(text, color)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
	if channel then
		pcall(function()
			channel:DisplaySystemMessage(('<font color="#%s"><b>%s</b></font>'):format(color:ToHex(), escapeRichText(text)))
		end)
	end
end

local banner -- the current banner label (a new announcement replaces it)

local function showBanner(text, color)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if banner then
		banner.Parent:Destroy()
		banner = nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Announcement"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.fromScale(0.7, 0.07)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.Parent = gui
	gui.Parent = playerGui
	banner = label

	local fade = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, fade, { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	task.delay(BANNER_SECONDS - FADE_SECONDS, function()
		if banner == label then
			TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(FADE_SECONDS, function()
				if banner == label then
					gui:Destroy()
					banner = nil
				end
			end)
		end
	end)
end

announce.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.Text) ~= "string" then
		return
	end
	local fx = ChestFxPresets.RarityFx[message.Rarity]
	local color = (fx and fx.Announce and fx.Announce.Color) or DEFAULT_COLOR
	showInChat(message.Text, color)
	showBanner(message.Text, color)
end)
