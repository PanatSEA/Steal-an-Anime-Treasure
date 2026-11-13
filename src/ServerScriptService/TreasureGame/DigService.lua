-- DigService: server side of digging with the Pickaxe (Phase 4).
-- The client only plays visuals and sends "DigHit" with the dig site. The server:
--   * checks the player is alive, has the Pickaxe equipped and is within MaxHitDistance,
--   * ignores hits closer together than MinHitIntervalSeconds,
--   * gives the dig to the first player who hits it; the claim lapses after
--     ClaimTimeoutSeconds without a hit, or if they walk ClaimMaxDistance away, die or leave,
--   * counts hits; only the final hit completes the dig (OnComplete rolls the rarity and wakes the boss).
-- State is published as attributes on the dig site model, which the client visuals follow:
--   DigState ("Locked" | "Buried" | "Emerged" | "Taken"), DigHits, DigHitsRequired,
--   DigOwner (UserId, 0 = nobody), Rarity (set on the final hit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Remotes = require(script.Parent.Remotes)

local Dig = AnimeConfig.Dig

local DigService = {}

local CLAIM_CHECK_TICK = 0.5

local sites = {} -- [Model] = { Model, Config, Anchor, Callbacks, State, Hits, Owner, LastHitAt }
local lastHitAt = {} -- [Player] = os.clock() of their last accepted hit

local digHit = Remotes.Event("DigHit")

local function publish(site)
	site.Model:SetAttribute("DigHits", site.Hits)
	site.Model:SetAttribute("DigOwner", site.Owner and site.Owner.UserId or 0)
	site.Model:SetAttribute("DigState", site.State)
end

local function aliveRoot(player)
	if player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function hasPickaxeEquipped(player)
	local tool = player.Character and player.Character:FindFirstChild(Dig.ToolName)
	return tool ~= nil and tool:IsA("Tool")
end

-- callbacks = { CanDig(player) -> bool, OnComplete(player) -> rarity }
function DigService.Register(model, cfg, callbacks)
	local anchor = model:WaitForChild("DigMound")
	-- The visible mound and chest are drawn by the client; the anchor only marks the spot.
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	local oldPrompt = anchor:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end

	local site = {
		Model = model,
		Config = cfg,
		Anchor = anchor,
		Callbacks = callbacks,
		State = "Locked",
		Hits = 0,
		Owner = nil,
		LastHitAt = 0,
	}
	sites[model] = site
	model:SetAttribute("DigHitsRequired", cfg.DigHitsRequired)
	model:SetAttribute("Rarity", nil)
	publish(site)
end

-- Buries a fresh chest under a new mound (called when the boss falls asleep).
function DigService.Reset(model)
	local site = sites[model]
	if not site then
		return
	end
	site.State = "Buried"
	site.Hits = 0
	site.Owner = nil
	model:SetAttribute("Rarity", nil)
	publish(site)
end

-- The emerged chest has left the node (it's on the digger's head, or was lost).
function DigService.SetTaken(model)
	local site = sites[model]
	if site and site.State == "Emerged" then
		site.State = "Taken"
		publish(site)
	end
end

digHit.OnServerEvent:Connect(function(player, model)
	local site = typeof(model) == "Instance" and sites[model] or nil
	if not site or site.State ~= "Buried" then
		return
	end
	local now = os.clock()
	if now - (lastHitAt[player] or 0) < Dig.MinHitIntervalSeconds then
		return
	end
	local root = aliveRoot(player)
	if not root or not hasPickaxeEquipped(player) then
		return
	end
	if (root.Position - site.Anchor.Position).Magnitude > Dig.MaxHitDistance then
		return
	end
	if site.Owner and site.Owner ~= player then
		return -- someone else claimed this dig first
	end
	if not site.Callbacks.CanDig(player) then
		return
	end

	lastHitAt[player] = now
	site.Owner = player
	site.Hits += 1
	site.LastHitAt = now
	if site.Hits >= site.Config.DigHitsRequired then
		site.State = "Emerged"
		model:SetAttribute("Rarity", site.Callbacks.OnComplete(player))
	end
	publish(site)
end)

-- Drop stale claims so the node doesn't stay locked to an absent player.
task.spawn(function()
	while true do
		task.wait(CLAIM_CHECK_TICK)
		for _, site in pairs(sites) do
			if site.State == "Buried" and site.Owner then
				local root = aliveRoot(site.Owner)
				local expired = not root
					or os.clock() - site.LastHitAt > Dig.ClaimTimeoutSeconds
					or (root.Position - site.Anchor.Position).Magnitude > Dig.ClaimMaxDistance
				if expired then
					site.Owner = nil
					site.Hits = 0
					publish(site)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHitAt[player] = nil
end)

return DigService
