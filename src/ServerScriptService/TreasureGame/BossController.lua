-- BossController: one boss per dig site.
-- States: Sleeping -> Chasing (on dig completed) -> Returning -> Sleeping.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimeConfig"))
local Zones = require(script.Parent.Zones)
local SkillPatterns = require(script.Parent.SkillPatterns)
local AudioConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AudioConfig"))
local ModelLoader = require(script.Parent.ModelLoader)

local BossController = {}
BossController.__index = BossController

local CHASE_TICK = 0.15
local RETURN_TICK = 0.25
local FIRST_SKILL_DELAY = 1

local STATE_TEXT = {
	Sleeping = "Zzz... Sleeping",
	Chasing = "!! CHASING !!",
	Returning = "Returning...",
}

-- Loads ReplicatedStorage.Models.Bosses.<BossId>, or a grey-box rig if it's missing.
local function buildBossModel(cfg)
	local model = ModelLoader.Boss(cfg.BossId)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.WalkSpeed = cfg.WalkSpeed

	local head = model:FindFirstChild("Head") or model.PrimaryPart
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 56)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 250
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = AnimeConfig.Rarities[cfg.Rarity].Color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = ("%s [%s]"):format(cfg.DisplayName, cfg.Rarity)
	nameLabel.Parent = billboard

	local stateLabel = Instance.new("TextLabel")
	stateLabel.Size = UDim2.fromScale(1, 0.45)
	stateLabel.Position = UDim2.fromScale(0, 0.55)
	stateLabel.BackgroundTransparency = 1
	stateLabel.Font = Enum.Font.GothamBold
	stateLabel.TextScaled = true
	stateLabel.TextColor3 = Color3.new(1, 1, 1)
	stateLabel.TextStrokeTransparency = 0.2
	stateLabel.Parent = billboard

	return model, humanoid, stateLabel
end

-- callbacks = { EffectsFolder, IsCarrying(player), OnPlayerHit(player), OnSleep() }
function BossController.new(site, cfg, callbacks)
	local self = setmetatable({}, BossController)
	self.Config = cfg
	self.Callbacks = callbacks
	self.SpawnPart = site:WaitForChild("BossSpawn")
	self.Model, self.Humanoid, self.StateLabel = buildBossModel(cfg)
	self.Root = self.Model.PrimaryPart
	self.Model.Parent = site
	self:Sleep()
	return self
end

function BossController:_homeCFrame()
	local spawn = self.SpawnPart
	local top = spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)
	local height = self.Humanoid.HipHeight + self.Root.Size.Y / 2
	return CFrame.new(top + Vector3.new(0, height, 0)) * spawn.CFrame.Rotation
end

function BossController:_setState(state)
	self.State = state
	self.Model:SetAttribute("BossState", state)
	self.StateLabel.Text = STATE_TEXT[state] or state
end

function BossController:Sleep()
	self.Target = nil
	self.Root.Anchored = true
	self.Model:PivotTo(self:_homeCFrame())
	self:_setState(self.Config.DefaultState or "Sleeping")
	if self.Callbacks.OnSleep then
		self.Callbacks.OnSleep()
	end
end

function BossController:Wake(player)
	if self.State ~= "Sleeping" then
		return
	end
	self.Target = player
	self:_setState("Chasing")
	self.Root.Anchored = false
	self.Root:SetNetworkOwner(nil)
	AudioConfig.Play("WakeUpSoundId", self.Root) -- 3D, follows the boss
	task.spawn(function()
		self:_chaseLoop()
	end)
end

function BossController:_targetRoot()
	local player = self.Target
	if not player or player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return root
end

function BossController:_castSkill(targetRoot)
	local cfg = self.Config
	local pattern = SkillPatterns[cfg.SkillPattern]
	if not pattern then
		warn(("[TreasureGame] Unknown SkillPattern %s for %s"):format(tostring(cfg.SkillPattern), cfg.BossId))
		return
	end
	task.spawn(pattern, {
		Config = cfg,
		BossModel = self.Model,
		TargetRoot = targetRoot,
		EffectsFolder = self.Callbacks.EffectsFolder,
		OnPlayerHit = self.Callbacks.OnPlayerHit,
	})
end

function BossController:_chaseLoop()
	local cfg = self.Config
	local nextSkillAt = os.clock() + math.min(FIRST_SKILL_DELAY, cfg.SkillCooldownSeconds)

	while self.State == "Chasing" do
		local root = self:_targetRoot()
		if not root or not self.Callbacks.IsCarrying(self.Target) then
			break
		end
		if cfg.ChaseStopInSafeZone and Zones.IsInSafeZone(root.Position) then
			break
		end

		self.Humanoid:MoveTo(root.Position)
		if os.clock() >= nextSkillAt then
			nextSkillAt = os.clock() + cfg.SkillCooldownSeconds
			self:_castSkill(root)
		end
		task.wait(CHASE_TICK)
	end

	if self.State == "Chasing" then
		self:_returnHome()
	end
end

-- Walks home and falls asleep exactly ReturnToSleepSeconds after the chase ends
-- (waits at home if it arrives early, snaps home if it is still walking).
function BossController:_returnHome()
	self:_setState("Returning")
	self.Target = nil
	local home = self:_homeCFrame().Position
	local sleepAt = os.clock() + self.Config.ReturnToSleepSeconds

	while self.State == "Returning" and os.clock() < sleepAt do
		local flat = (self.Root.Position - home) * Vector3.new(1, 0, 1)
		if flat.Magnitude >= 3 then
			self.Humanoid:MoveTo(home)
		end
		task.wait(RETURN_TICK)
	end

	if self.State == "Returning" then
		self:Sleep()
	end
end

return BossController
