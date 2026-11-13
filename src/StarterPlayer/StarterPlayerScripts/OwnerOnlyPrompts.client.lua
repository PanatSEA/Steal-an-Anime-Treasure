-- OwnerOnlyPrompts: hides "Sell" prompts on other players' plots.
-- The server still checks ownership; this only keeps other players' prompts off screen.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local TAG = "OwnerOnlyPrompt"
local localPlayer = Players.LocalPlayer

local function apply(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function update()
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == localPlayer.UserId
	end
	update()
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
end

for _, prompt in ipairs(CollectionService:GetTagged(TAG)) do
	apply(prompt)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
