-- ChestAura: the rarity aura on every chest (client, visual only). Replaces ChestGoldAura.
-- Chests tagged TreasureModels.AURA_TAG get the look of their rarity from
-- ChestFxPresets.RarityFx (built by ReplicatedStorage.Shared.ChestAura): glow, gem light,
-- sparkles, sky beam and a shimmer flash every few seconds.
-- The server tags carried and plot chests (Carry.MakeTreasure); DigClient tags the chest when
-- it emerges. The aura stops when the chest starts opening (Opening attribute) or is removed.
-- Keeping it light (ChestFxPresets.ChestAura):
--   * further than CullDistance from the camera: everything off, except a beam marked
--     AlwaysVisible (the Secret beam, seen across the track)
--   * the sky beam is off while the chest is carried
--   * only the nearest MaxLights chests light their gem, and only the nearest MaxSparkleChests
--     run their sparkle loop (fewer on mobile, at MobileRateMul)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TreasureModels = require(Shared:WaitForChild("TreasureModels"))
local VfxPlayer = require(Shared:WaitForChild("VfxPlayer"))
local ChestFxPresets = require(Shared:WaitForChild("ChestFxPresets"))
local ChestAura = require(Shared:WaitForChild("ChestAura"))

local Config = ChestFxPresets.ChestAura
local Shimmer = ChestFxPresets.ChestShimmer
local TAG = TreasureModels.AURA_TAG
local CHECK_SECONDS = 0.25
local ROOT_WAIT_SECONDS = 5 -- a streamed-in chest may arrive before its PrimaryPart

local mobile = VfxPlayer.IsMobile
local maxLights = mobile and Config.MaxLightsMobile or Config.MaxLights
local maxSparkles = mobile and Config.MaxSparkleChestsMobile or Config.MaxSparkleChests
local sparkleRateMul = mobile and Config.MobileRateMul or 1

local auras = {} -- [chest Model] = { Aura, Connections, NextShimmer, Near }

local function nextShimmerAt(now)
	return now + Shimmer.Interval.Min + math.random() * (Shimmer.Interval.Max - Shimmer.Interval.Min)
end

local function detach(model)
	local entry = auras[model]
	if not entry then
		return
	end
	auras[model] = nil
	for _, connection in ipairs(entry.Connections) do
		connection:Disconnect()
	end
	ChestAura.Destroy(entry.Aura)
end

local function attach(model)
	if auras[model] or not model:IsA("Model") or not model:IsDescendantOf(Workspace) or model:GetAttribute("Opening") then
		return
	end
	local deadline = os.clock() + ROOT_WAIT_SECONDS
	while not model.PrimaryPart and os.clock() < deadline and model.Parent do
		task.wait(0.1)
	end
	if not model.PrimaryPart or auras[model] or not model:IsDescendantOf(Workspace) or not CollectionService:HasTag(model, TAG) then
		return
	end
	local aura = ChestAura.Build(model)
	if not aura then
		return
	end
	local entry = { Aura = aura, Connections = {}, NextShimmer = nextShimmerAt(os.clock()), Near = false }
	auras[model] = entry
	table.insert(entry.Connections, model:GetAttributeChangedSignal("Opening"):Connect(function()
		if model:GetAttribute("Opening") then
			detach(model) -- the opening effect takes over
		end
	end))
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(attach, model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
	task.spawn(attach, model)
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach) -- untagged, destroyed or streamed out

-- Carried chests sit in a character model (welded on its head).
local function isCarried(model)
	local parent = model.Parent
	return parent ~= nil and parent:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Decides what each chest shows: distance, carried, and the light / sparkle limits.
local function refresh()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local near = {}
	for model, entry in pairs(auras) do
		local aura = entry.Aura
		local distance = (aura.Attachment.WorldPosition - cameraPosition).Magnitude
		entry.Distance = distance
		entry.Near = distance <= Config.CullDistance
		ChestAura.SetHalo(aura, entry.Near)
		local sky = aura.Fx.SkyBeam
		ChestAura.SetBeam(aura, sky ~= nil and not isCarried(model) and (entry.Near or sky.AlwaysVisible == true))
		if entry.Near then
			table.insert(near, entry)
		end
	end
	table.sort(near, function(a, b)
		return a.Distance < b.Distance
	end)
	local lights, sparkles = 0, 0
	local lit, sparkling = {}, {}
	for _, entry in ipairs(near) do
		if lights < maxLights then
			lights += 1
			lit[entry] = true
		end
		if ChestAura.HasSparkles(entry.Aura) and sparkles < maxSparkles then
			sparkles += 1
			sparkling[entry] = true
		end
	end
	for _, entry in pairs(auras) do
		ChestAura.SetLight(entry.Aura, lit[entry] == true)
		ChestAura.SetSparkles(entry.Aura, sparkling[entry] == true, sparkleRateMul)
	end
end

local nextRefresh = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now >= nextRefresh then
		nextRefresh = now + CHECK_SECONDS
		refresh()
	end
	for _, entry in pairs(auras) do
		ChestAura.Update(entry.Aura, now)
		if entry.Near and now >= entry.NextShimmer then
			entry.NextShimmer = nextShimmerAt(now)
			ChestAura.Shimmer(entry.Aura)
		end
	end
end)
