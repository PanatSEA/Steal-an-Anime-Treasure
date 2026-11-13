-- OwnerOnlyPrompts: shows chest "Open" prompts only to the plot owner, and only
-- once the chest is unlocked (Ready). The server still checks both before opening.
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
			and prompt:GetAttribute("Ready") ~= false
	end
	update()
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
	prompt:GetAttributeChangedSignal("Ready"):Connect(update)
end

for _, prompt in ipairs(CollectionService:GetTagged(TAG)) do
	apply(prompt)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
