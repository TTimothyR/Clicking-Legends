local ClickHandler = {}
local db: boolean = false

-- Services
local players = game:GetService("Players")
local ts = game:GetService("TweenService")
local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local debris = game:GetService("Debris")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local plr: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local assets = rs:WaitForChild("Assets")
local clickModels = assets:WaitForChild("ClickModels")
local criticalModel = clickModels:WaitForChild("CriticalClick")
local library = framework:WaitForChild("Library")
local cpsNumber = script:WaitForChild("CPSNumber")
local criticalEffects = script:WaitForChild("Critical")

local rng = Random.new()
local statsLoaded = false

-- UI
local playerGui = plr:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HUD")
local clickButton = hud:WaitForChild("Click")

local autoClickerFrame = hud:WaitForChild("AutoClicker")
local toggleButton = autoClickerFrame:WaitForChild("Toggle")

local left = hud:WaitForChild("Left")
local statsFrame = left:WaitForChild("Stats")

local popUpArea = hud:WaitForChild("PopUpArea")
local popUps = hud:WaitForChild("PopUps")
local popUpTemplate = hud:WaitForChild("PopUpTemplate")

local shine = clickButton:WaitForChild("Shine")
local template = clickButton:WaitForChild("Template")
local animationFrames = clickButton:WaitForChild("AnimationFrames")

-- Modules
local network = require(framework.Network)
local infMath = require(framework.InfiniteMath)
local globals = require(framework.Globals)
local imageService = require(library.ImageService)
local dataSync = require(script.Parent.DataSyncClient)

-- Constants
local rotationTime: number = 15
local animationTime: number = 0.5
local debounceTime: number = 0.15
local textEndSize: UDim2 = UDim2.fromScale(1, 0.5)
local characterGroup = "CHAR"
local debrisGroup = "DEBRIS"

-- Globals
local animationData = {}
local autoClickStatus = false

local function SetupCharacter(character)
	for _, effect: ParticleEmitter in ipairs(criticalEffects:GetChildren()) do
		local clone: ParticleEmitter = effect:Clone()
		clone.Parent = character:WaitForChild("HumanoidRootPart")
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = characterGroup
		end
	end

	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = characterGroup
		end
	end)
end

local function AnimateShine()
	while true do
		local tween1: Tween = ts:Create(
			shine,
			TweenInfo.new(rotationTime / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Rotation = 360 }
		)
		tween1:Play()
		tween1.Completed:Wait()
		shine.Rotation = 0
	end
end

local function ClickAnimation()
	local clone: Frame = template:Clone()
	clone.Parent = animationFrames

	clone:TweenSize(UDim2.fromScale(1.25, 1.25), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, animationTime)
	local tween: Tween = ts:Create(
		clone,
		TweenInfo.new(animationTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()

	clone:Destroy()
end

local function CriticalHitEffect()
	local character = plr.Character
	local root = character.HumanoidRootPart

	if not root then
		return
	end
	for _, child: Instance in ipairs(root:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(50)
		end
	end

	for _ = 1, 10 do
		task.spawn(function()
			local clone = criticalModel:Clone()

			if not clone.PrimaryPart then
				clone:Destroy()
			end

			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanQuery = false
					part.CollisionGroup = debrisGroup
				end
			end

			clone:PivotTo(root.CFrame * CFrame.new(0, 2, 0))
			clone.Parent = workspace
			local force = 15
			local xForce = rng:NextNumber(-force, force)
			local zForce = rng:NextNumber(-force, force)
			local yForce = rng:NextNumber(30, 60)

			local jumpVector = Vector3.new(xForce, yForce, zForce)

			clone.PrimaryPart:ApplyImpulse(jumpVector * clone.PrimaryPart.AssemblyMass)

			local randomRot = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))

			clone.PrimaryPart:ApplyAngularImpulse(randomRot * clone.PrimaryPart.AssemblyMass)

			debris:AddItem(clone, 5)
		end)
	end
end

function ClickHandler.PopUp(increment, currencyStr: string, critical: boolean?, position: UDim2?)
	if not increment or increment == infMath.new(0) then
		return
	end

	if not position then
		local randomX = rng:NextNumber(popUpArea.Position.X.Scale, popUpArea.Position.X.Scale + popUpArea.Size.Width.Scale)
		local randomY = rng:NextNumber(popUpArea.Position.Y.Scale, popUpArea.Position.Y.Scale + popUpArea.Size.Width.Scale)

		position = UDim2.fromScale(randomX, randomY)
	end

	local clone = popUpTemplate:Clone()
	local extraImgFrames: Folder = clone.ExtraImgFrames
	clone.Parent = popUps
	clone.Icon.Image = imageService[currencyStr]

	if critical then
		clone.Icon.ImageColor3 = Color3.fromRGB(237, 98, 255)
		task.spawn(CriticalHitEffect)
	end

	clone.Position = position
	clone.Size = UDim2.new(0, 0, 0, 0)
	clone.Visible = true

	local animTime: number = 0.3
	local style = Enum.EasingStyle.Back
	local style2 = Enum.EasingStyle.Linear
	local direction = Enum.EasingDirection.Out
	local direction2 = Enum.EasingDirection.In

	local popUpEndSize: UDim2 = critical and UDim2.fromScale(2 * 0.042, 2 * 0.065) or UDim2.fromScale(0.042, 0.065)

	clone:TweenSize(popUpEndSize, direction, style, animTime)
	local tween: Tween = ts:Create(clone, TweenInfo.new(animTime, style, direction), { Rotation = 0 })
	tween:Play()
	tween.Completed:Wait()

	local incrementText = clone.Increment
	incrementText.Text = "+" .. infMath.new(increment):GetSuffix(true)
	local textTween: Tween =
		ts:Create(incrementText, TweenInfo.new(animTime / 2, style2, direction), { TextTransparency = 0 })
	textTween:Play()
	ts:Create(incrementText.UIStroke, TweenInfo.new(animTime / 2, style2, direction), { Transparency = 0 }):Play()
	incrementText:TweenSize(textEndSize, direction2, style, animTime)
	textTween.Completed:Wait()

	local amount: number = critical and 20 or 10

	for _ = 0, amount do
		task.spawn(function()
			local imgClone: ImageLabel = clone.Icon:Clone()
			imgClone.Parent = extraImgFrames

			imgClone:TweenSize(UDim2.fromScale(1.75, 1.75), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, animTime)
			local transparencyTween: Tween = ts:Create(
				imgClone,
				TweenInfo.new(animTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
				{ ImageTransparency = 1 }
			)
			transparencyTween:Play()
			transparencyTween.Completed:Wait()

			imgClone:Destroy()
		end)
		task.wait(0.1)
	end

	repeat
		task.wait()
	until #extraImgFrames:GetChildren() == 0

	clone:TweenSize(UDim2.new(0, 0, 0, 0), direction2, style, animTime)
	local returnTween: Tween = ts:Create(clone, TweenInfo.new(animTime, style, direction2), { Rotation = 180 })
	returnTween:Play()
	returnTween.Completed:Wait()

	clone:Destroy()
end

local function UpdateStatDisplay(currencyStr: string, newValue)
	if not statsLoaded then
		return
	end
	local currencyFrame = statsFrame[currencyStr]
	local goalValue: number = 1

	local data = animationData[currencyStr]

	if data.activeTween then
		data.activeTween:Cancel()
	end

	if data.activeConnection then
		data.activeConnection:Disconnect()
	end
	data.currentAnimValue = infMath.new(data.currentValue)

	local startValue = data.currentValue
	local delta = infMath.new(newValue - startValue)

	if currencyStr == "Gems" then
		task.spawn(ClickHandler.PopUp, delta, currencyStr)
	end

	data.tweenNumber.Value = 0
	data.activeTween = ts:Create(data.tweenNumber, TweenInfo.new(0.3), { Value = goalValue })
	data.activeConnection = data.tweenNumber.Changed:Connect(function(value)
		data.currentAnimValue = infMath.new(startValue + (delta * value))
		currencyFrame.Background.Amount.Text = data.currentAnimValue:GetSuffix(true)
	end)
	data.activeTween:Play()
	data.currentValue = newValue
end

local function ClickByButton()
	local s, increment, critical = network:InvokeServer("Click")
	if not s then
		return
	end

	task.spawn(ClickAnimation)
	task.spawn(ClickHandler.PopUp, increment, "Clicks", critical)
end

local function ClickByScreen(inputPosition)
	local s, increment, critical = network:InvokeServer("Click")
	if not s then
		return
	end
	local guiInset = guiService:GetGuiInset()

	task.spawn(
		ClickHandler.PopUp,
		increment,
		"Clicks",
		critical,
		UDim2.fromOffset(inputPosition.X, inputPosition.Y + guiInset.Y)
	)
end

local function StartCPSTrack()
	local currencyFrame = statsFrame.Clicks
	local cpsText = currencyFrame.Background.CPS
	cpsText.Text = "0/s"

	local startClicks = dataSync.Get("Clicks")

	local lastClickTable
	if startClicks then
		lastClickTable = startClicks
	else
		lastClickTable = infMath.new(0)
	end
	local updateTime: number = 1

	local currentTween: Tween = nil
	local currentConnection: RBXScriptConnection = nil
	local currentCPS = infMath.new(0)
	local goalValue: number = 1

	while true do
		task.wait(updateTime)
		if currentTween then
			currentTween:Cancel()
		end
		if currentConnection then
			currentConnection:Disconnect()
		end

		local currentClicks = dataSync.Get("Clicks")
		if currentClicks then
			local currentRaw = currentClicks
			local currentTbl = infMath.new(currentRaw)

			local cps = infMath.new(currentTbl - lastClickTable)

			local startValue = currentCPS
			local delta = infMath.new(cps - startValue)

			cpsNumber.Value = 0
			currentTween = ts:Create(cpsNumber, TweenInfo.new(0.3), { Value = goalValue })

			currentConnection = cpsNumber.Changed:Connect(function(value)
				currentCPS = infMath.new(startValue + (delta * value))
				cpsText.Text = currentCPS:GetSuffix(true) .. "/s"
			end)
			currentTween:Play()
			lastClickTable = currentTbl
		end
	end
end

-- local function AutoClick()
--     while task.wait(debounceTime) do
--         if not autoClickStatus then continue end

--         local increment, critical = network:InvokeServer('Click');
--         if critical then
--             task.spawn(CriticalHitEffect);
--         end
--         task.spawn(PopUp, increment, 'Clicks', critical);
--     end
-- end

local function UpdateAutoClickButton(status: boolean)
	local color = ""
	local text = ""
	if status then
		color = "Green"
		text = "On"
	else
		color = "Red"
		text = "Off"
	end
	toggleButton.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	toggleButton.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	toggleButton.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	toggleButton.Title.Text = text
end

local function LoadStatDisplay(currency, value)
	local numValue = Instance.new("NumberValue")
	numValue.Parent = script
	numValue.Name = currency
	numValue.Value = 0

	animationData[currency] = {
		currentValue = infMath.new(value),
		currentAnimValue = infMath.new(0),
		activeTween = ts:Create(numValue, TweenInfo.new(0), { Value = 0 }),
		activeConnection = nil,
		tweenNumber = numValue,
	}
end

local function LoadAutoClickerUnlock()
	local upgradeLevels = dataSync.Get("UpgradeLevels")

	toggleButton.Locked.Visible = (upgradeLevels["Auto Clicker"] == 0)
end

function ClickHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	task.spawn(AnimateShine)
	task.spawn(StartCPSTrack)
	-- task.spawn(AutoClick);

	SetupCharacter(plr.Character)

	uis.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ClickByScreen(input.Position)
		end
	end)

	clickButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(debounceTime, function()
				db = false
			end)
			ClickByButton()
		end
	end)

	toggleButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(debounceTime, function()
				db = false
			end)
			network:FireServer("ToggleAutoClicker")
		end
	end)

	dataSync.OnReady(function()
		local targetClicks = dataSync.Get("Clicks")
		local targetGems = dataSync.Get("Gems")
		task.spawn(UpdateStatDisplay, "Clicks", targetClicks)
		task.spawn(UpdateStatDisplay, "Gems", targetGems)
		task.spawn(LoadStatDisplay, "Clicks", targetClicks)
		task.spawn(LoadStatDisplay, "Gems", targetGems)
		task.spawn(LoadAutoClickerUnlock)

		autoClickStatus = dataSync.Get("AutoClickerStatus")
		UpdateAutoClickButton(autoClickStatus)

		statsLoaded = true
	end)

	dataSync.OnChanged("Clicks", function(newValue, _)
		task.spawn(UpdateStatDisplay, "Clicks", newValue)
	end)

	dataSync.OnChanged("Gems", function(newValue, _)
		task.spawn(UpdateStatDisplay, "Gems", newValue)
	end)

	dataSync.OnChanged("AutoClickerStatus", function(new)
		autoClickStatus = new
		UpdateAutoClickButton(autoClickStatus)
	end)

	dataSync.OnChanged("UpgradeLevels", function(new, old)
		if new["Auto Clicker"] == 1 then
			toggleButton.Locked.Visible = false
		end
		if new and old then
			if new["Faster Auto Click"] and old["Faster Auto Click"] then
				if new["Faster Auto Click"] ~= old["Faster Auto Click"] then
					network:FireServer("IncreaseAutoClickSpeed")
				end
			end
		end
	end)

	-- plr:GetAttributeChangedSignal('Clicks'):Connect(function()
	--     task.spawn(UpdateStatDisplay, 'Clicks');
	-- end)

	-- plr:GetAttributeChangedSignal('Gems'):Connect(function()
	--     task.spawn(UpdateStatDisplay, 'Gems');
	-- end)
end

return ClickHandler
