-- ChestFx: lid-opening and coin-pop animation when the server opens a chest on a plot.
-- Visual only; the server has already decided the character.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local treasureFx = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("TreasureFx")

local LID_OPEN_DEGREES = 110
local LID_OPEN_SECONDS = 0.45
local COIN_COUNT = 12
local COIN_COLOR = Color3.fromRGB(255, 205, 60)

local function tweenNumber(from, to, seconds, style, direction, onStep)
	local value = Instance.new("NumberValue")
	value.Value = from
	local connection = value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = to })
	tween.Completed:Connect(function()
		connection:Disconnect()
		value:Destroy()
	end)
	tween:Play()
end

local function popCoins(model)
	local base = model.PrimaryPart
	if not base then
		return
	end
	local origin = base.Position + Vector3.new(0, base.Size.Y / 2 + 0.4, 0)
	for _ = 1, COIN_COUNT do
		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.15, 0.8, 0.8)
		coin.Color = COIN_COLOR
		coin.Material = Enum.Material.Metal
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CanTouch = false
		coin.CFrame = CFrame.new(origin) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		coin.Parent = Workspace
		coin.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(22, 32), math.random(-8, 8))
		coin.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		task.delay(0.7, function()
			if coin.Parent then
				TweenService:Create(coin, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(coin, 1.2)
	end
end

local function openChest(model)
	local lid = model:FindFirstChild("Lid")
	if lid and lid:IsA("Model") and lid.PrimaryPart then
		local closed = lid:GetPivot()
		-- The lid's pivot sits on the back hinge; rotating about its X axis lifts the front.
		tweenNumber(0, 1, LID_OPEN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
			if lid.Parent then
				lid:PivotTo(closed * CFrame.Angles(math.rad(LID_OPEN_DEGREES * alpha), 0, 0))
			end
		end)
	end
	task.delay(0.2, popCoins, model)
end

treasureFx.OnClientEvent:Connect(function(kind, model)
	if kind == "ChestOpen" and typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
		openChest(model)
	end
end)
