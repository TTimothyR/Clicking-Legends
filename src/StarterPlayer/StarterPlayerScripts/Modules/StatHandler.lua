local ClickHandler = {}
local db: boolean = false

-- Services
local players = game:GetService("Players")
local ts = game:GetService("TweenService")
local rs = game:GetService("ReplicatedStorage")
local uis = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local debris = game:GetService("Debris")

local Assets = rs:WaitForChild("Assets")

local Sounds = Assets:WaitForChild("Sounds")

local Framework = rs:WaitForChild("Framework")

local InterfaceUtility = require(Framework:WaitForChild("InterfaceUtility"))

local SoundHandler = require("./SoundHandler")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local plr: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local assets = rs:WaitForChild("Assets")
local clickModels = assets:WaitForChild("ClickModels")
local criticalModel = clickModels:WaitForChild("CriticalClick") :: Model
local library = framework:WaitForChild("Library")
local cpsNumber = script:WaitForChild("CPSNumber")
local criticalEffects = script:WaitForChild("Critical")

local trackerThread: thread? = nil

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

local PopupSizeEnd = UDim2.fromScale(0.04, 0.04)

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

local buttonTween = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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
			part.CollisionGroup = globals.CharacterGroup
		end
	end

	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = globals.CharacterGroup
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

local function CriticalHitEffect()
	local character = plr.Character
	local root = character.HumanoidRootPart

	if not root then
		return
	end
	local lowDetail = dataSync.Get("Settings").LowDetail
	if not lowDetail then
		for _, child: Instance in ipairs(root:GetChildren()) do
			if child:IsA("ParticleEmitter") and child.Name ~= "Cuts" then
				child:Emit(50)
			end
		end
	end

	SoundHandler.PlaySound(Sounds.Critical)

	if not lowDetail then
		for _ = 1, 10 do
			task.spawn(function()
				local clone = criticalModel:Clone()

				if not clone.PrimaryPart then
					clone:Destroy()
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

				debris:AddItem(clone, 2)
			end)
		end
	end
end

local function GenerateX()
	return math.random() * (0.88 - 0.35) + 0.35
end

local function GenerateY()
	return math.random() * (0.75 - 0.15) + 0.15
end

local function getRandomPopupPosition(customX, customY)
	return UDim2.fromScale((customX or GenerateX()), (customY or GenerateY()))
end

function ClickHandler.PlayRebirthAnimation(amount)
	task.spawn(function()
		local popup = script.CurrencyPopup:Clone()
		popup.Size = UDim2.fromScale(0.15, 0.15)
		popup.Icon.Image = imageService["More Rebirths"]
		popup.Parent = playerGui.Frames
		popup.Amount.Text = amount
		popup.UIGradient:Destroy()
		popup.UIStroke:Destroy()
		popup.BackgroundTransparency = 1

		local yPos = GenerateY()
		popup.Position = UDim2.fromScale(yPos, 0)

		local tween = ts:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = getRandomPopupPosition(nil, yPos),
		})
		tween:Play()
		tween.Completed:Wait()
		task.delay(0.15, function()
			tween = ts:Create(popup.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Rotation = 360,
			})
			tween:Play()
			tween.Completed:Wait()
			tween = ts:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0, 0),
			})
			tween:Play()
			tween.Completed:Wait()
			popup:Destroy()
		end)
	end)
end

local function getStatIconPosition(currencyName)
	local statFrame = statsFrame:FindFirstChild(currencyName)
	if not statFrame then
		return nil
	end
	local icon = statFrame:FindFirstChild("Icon")
	if not icon then
		return nil
	end

	local absPos = icon.AbsolutePosition
	local absSize = icon.AbsoluteSize

	return UDim2.fromOffset(absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2)
end

local function spawnCurrencyPopup()
	local popupsEnabled = dataSync.Get("Settings").ClickPopups
	local iconImage = "rbxassetid://111160873357689"
	if not iconImage or not popupsEnabled then
		return
	end

	local popup = script.CurrencyPopup:Clone()
	local amountLabel = popup:FindFirstChild("Amount")
	local amountStroke = amountLabel and amountLabel:FindFirstChildOfClass("UIStroke")

	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = getRandomPopupPosition()
	--popup.Size = PopupSizeSmall -- start small
	--popup.Image = iconImage
	--popup.ImageTransparency = 1
	--popup.Amount.Text = amount
	popup.Visible = true

	if amountLabel then
		--amountLabel.Text = "+" .. amount.second
		--amountLabel.TextTransparency = 1
		if amountStroke then
			amountStroke.Transparency = 1
		end
		amountLabel.Visible = false
	end
	popup.Parent = playerGui.HUD

	-- Pop-in: grow + fade in
	--ts:Create(popup.Icon, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	--	ImageTransparency = 0,
	--	Size = PopupSize
	--}):Play()
	--if amountLabel then
	--	ts:Create(amountLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	--		TextTransparency = 0,
	--	}):Play()
	--	if amountStroke then
	--		ts:Create(amountStroke, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	--			Transparency = 0
	--		}):Play()
	--	end
	--end

	-- Fly toward stat icon + fade out
	task.delay(0.2, function()
		local targetPos = getStatIconPosition("Clicks")
		if not targetPos then
			popup:Destroy()
			return
		end

		local twn = ts:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = targetPos,
			Size = PopupSizeEnd,
		})
		twn:Play()

		twn.Completed:Wait()
		popup:Destroy()

		--if amountLabel then
		--	ts:Create(amountLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		--		TextTransparency = 1,
		--	}):Play()
		--	if amountStroke then
		--		local strokeFade = ts:Create(amountStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		--			Transparency = 1
		--		})
		--		strokeFade:Play()
		--		strokeFade.Completed:Connect(function()
		--			popup:Destroy()
		--		end)
		--	else
		--		task.delay(0.35, function()
		--			popup:Destroy()
		--		end)
		--	end
		--else
		--	task.delay(0.35, function()
		--		popup:Destroy()
		--	end)
		--end
	end)
end

function ClickHandler.PlayGemAnimation()
	local targetPos = getStatIconPosition("Gems")

	for _ = 1, math.random(3, 6) do
		task.spawn(function()
			local popup = script.CurrencyPopup:Clone()
			popup.Size = UDim2.fromScale(0, 0)
			popup.Parent = playerGui.Frames
			popup.UIGradient:Destroy()
			popup.UIStroke:Destroy()
			popup.BackgroundTransparency = 1
			popup.Position = getRandomPopupPosition()
			popup.Icon.Image = imageService.Gems
			popup.Size = UDim2.fromScale(0.042, 0.065)
			popup.Visible = true
			popup.ZIndex = 1000
			popup.Amount.Visible = false

			local sizeTwn = ts:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.125, 0.125),
			})
			sizeTwn:Play()
			sizeTwn.Completed:Wait()
			task.delay(0.15, function()
				local twn = ts:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = targetPos,
				})
				twn:Play()
				twn.Completed:Wait()
				popup:Destroy()
			end)
		end)
	end
end

function ClickHandler.PopUp(increment, currencyStr: string, critical: boolean?, position: UDim2?, isScreen: boolean)
	--warn(increment.. " - from PopUp Function")
	local popupsEnabled = dataSync.Get("Settings").ClickPopups
	if not increment or infMath.new(increment) <= infMath.new(0) or not popupsEnabled then
		return
	end

	if not position then
		local randomX = rng:NextNumber(popUpArea.Position.X.Scale, popUpArea.Position.X.Scale + popUpArea.Size.Width.Scale)
		local randomY = rng:NextNumber(popUpArea.Position.Y.Scale, popUpArea.Position.Y.Scale + popUpArea.Size.Width.Scale)

		position = UDim2.fromScale(randomX, randomY)
	end

	local clone = popUpTemplate:Clone()
	clone.Parent = popUps
	clone.Icon.Image = imageService[currencyStr]

	if critical then
		clone.Icon.ImageColor3 = Color3.fromRGB(237, 98, 255)
		task.spawn(CriticalHitEffect)
		InterfaceUtility.PlayScreenGlow(playerGui.Glow, Color3.fromRGB(237, 98, 255), 0.25, 0.25)
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

	task.spawn(function()
		if typeof(isScreen) == "boolean" and isScreen == true then
			local UIScale = clone.UIScale
			local UIStroke = clone.UIStroke

			ts:Create(UIScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1.3 }):Play()
			ts:Create(UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end)

	local incrementText = clone.Increment
	incrementText.Text = "+" .. infMath.new(increment):GetSuffix(true)
	local textTween: Tween =
		ts:Create(incrementText, TweenInfo.new(animTime / 2, style2, direction), { TextTransparency = 0 })
	textTween:Play()
	ts:Create(incrementText.UIStroke, TweenInfo.new(animTime / 2, style2, direction), { Transparency = 0 }):Play()
	incrementText:TweenSize(textEndSize, direction2, style, animTime)
	textTween.Completed:Wait()

	task.delay(0.5, function()
		clone:TweenSize(UDim2.new(0, 0, 0, 0), direction2, style, animTime)
		local returnTween: Tween = ts:Create(clone, TweenInfo.new(animTime, style, direction2), { Rotation = 180 })
		returnTween:Play()
		returnTween.Completed:Wait()

		clone:Destroy()
	end)
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

	task.spawn(function()
		local tween = ts:Create(
			currencyFrame,
			TweenInfo.new(0.05, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(0.937, 0.449) }
		)
		tween:Play()
		tween.Completed:Wait()

		ts:Create(currencyFrame, buttonTween, { Size = UDim2.fromScale(0.855, 0.367) }):Play()
	end)

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

	InterfaceUtility.PlayWhiteOutAnim(template, animationFrames, animationTime)
	task.spawn(ClickHandler.PopUp, increment, "Clicks", critical)
	spawnCurrencyPopup()
	SoundHandler.PlaySound(Sounds.Tap)
end

-- local function animateButton(button: ImageButton)
-- 	task.spawn(function()
-- 		local mouseEnter: RBXScriptConnection
-- 		local mouseLeave: RBXScriptConnection
-- 		local mouseDown: RBXScriptConnection
-- 		local mouseUp: RBXScriptConnection
-- 		local attributeChange: RBXScriptConnection

-- 		local originalSize: UDim2 = button.Size

-- 		local hoverScale = button:GetAttribute("Scale") or 1
-- 		local clickScale: number = 1 - (hoverScale - 1) or 1

-- 		local hoverSize: UDim2 = UDim2.new(
-- 			originalSize.X.Scale * hoverScale,
-- 			originalSize.X.Offset,
-- 			originalSize.Y.Scale * hoverScale,
-- 			originalSize.Y.Offset
-- 		)
-- 		local clickSize = UDim2.new(
-- 			originalSize.X.Scale * clickScale,
-- 			originalSize.X.Offset,
-- 			originalSize.Y.Scale * clickScale,
-- 			originalSize.Y.Offset
-- 		)

-- 		local isHovering: boolean = false
-- 		--local rotateTween: Tween = ts:Create(button, buttonTween, { Rotation = rotation })
-- 		--local rotateTween2: Tween = ts:Create(button, buttonTween, { Rotation = originalRotation })

-- 		mouseEnter = button.MouseEnter:Connect(function()
-- 			isHovering = true
-- 			button:TweenSize(hoverSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.2, true)
-- 			--rotateTween:Play()
-- 		end)
-- 		mouseLeave = button.MouseLeave:Connect(function()
-- 			isHovering = false
-- 			button:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.2, true)
-- 			--rotateTween2:Play()
-- 		end)
-- 		mouseDown = button.MouseButton1Down:Connect(function()
-- 			button:TweenSize(clickSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.2, true)
-- 		end)
-- 		mouseUp = button.MouseButton1Up:Connect(function()
-- 			if isHovering == true then
-- 				button:TweenSize(hoverSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.2, true)
-- 			elseif isHovering == false then
-- 				button:TweenSize(originalSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.2, true)
-- 			end
-- 		end)
-- 		button:GetPropertyChangedSignal("Parent"):Once(function()
-- 			if button.Parent == nil then
-- 				mouseEnter:Disconnect()
-- 				mouseLeave:Disconnect()
-- 				mouseDown:Disconnect()
-- 				mouseUp:Disconnect()
-- 			end
-- 		end)
-- 		attributeChange = button:GetAttributeChangedSignal("Scale"):Connect(function()
-- 			if button:GetAttribute("Scale") == nil then
-- 				mouseEnter:Disconnect()
-- 				mouseLeave:Disconnect()
-- 				mouseDown:Disconnect()
-- 				mouseUp:Disconnect()
-- 				attributeChange:Disconnect()
-- 			end
-- 		end)
-- 	end)
-- end

local function PlayClickEFX()
	local character = plr.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local lowDetail = dataSync.Get("Settings").LowDetail

	local effect = script.ClickEfx:Clone()
	local cuts = script.Cuts:Clone()
	effect.Enabled = false
	cuts.Enabled = false
	effect.Parent = humanoidRootPart
	cuts.Parent = humanoidRootPart
	debris:AddItem(effect, 0.5)
	debris:AddItem(cuts, 0.5)
	if not lowDetail then
		effect:Emit(math.random(2, 5))
		cuts:Emit(5)
	end
	task.wait(0.1)
end

local originalButtonSize: UDim2 = clickButton.Size
local isAnimating = false

local function ForceButtonAnimation()
	if isAnimating then
		return
	end
	isAnimating = true

	local button = clickButton
	local clickScale: number = 0.9
	local clickSize = UDim2.new(
		originalButtonSize.X.Scale * clickScale,
		originalButtonSize.X.Offset,
		originalButtonSize.Y.Scale * clickScale,
		originalButtonSize.Y.Offset
	)

	button:TweenSize(clickSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.06, true)
	task.delay(0.06, function()
		button:TweenSize(originalButtonSize, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.1, true)
		task.delay(0.1, function()
			isAnimating = false
		end)
	end)
end

local function ClickByScreen(inputPosition)
	local s, increment, critical = network:InvokeServer("Click")
	if not s then
		return
	end
	local guiInset = guiService:GetGuiInset()

	InterfaceUtility.PlayWhiteOutAnim(template, animationFrames, animationTime)
	task.spawn(
		ClickHandler.PopUp,
		increment,
		"Clicks",
		critical,
		UDim2.fromOffset(inputPosition.X, inputPosition.Y + guiInset.Y),
		true
	)
	PlayClickEFX()
	ForceButtonAnimation()
	spawnCurrencyPopup()
	SoundHandler.PlaySound(Sounds.Tap)
end

local function StartCPSTrack()
	if trackerThread then
		task.cancel(trackerThread)
	end
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

	trackerThread = task.spawn(function()
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

				local cps = currentTbl - lastClickTable
				if cps < infMath.new(0) then
					cps = infMath.new(0)
				end

				local startValue = currentCPS
				local delta = cps - startValue

				cpsNumber.Value = 0
				currentTween = ts:Create(cpsNumber, TweenInfo.new(0.3), { Value = goalValue })

				currentConnection = cpsNumber.Changed:Connect(function(value)
					currentCPS = startValue + (delta * value)
					cpsText.Text = currentCPS:GetSuffix(true) .. "/s"
				end)
				currentTween:Play()
				lastClickTable = currentTbl
			end
		end
	end)
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
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	for _, part in ipairs(criticalModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanQuery = false
			part.CanCollide = false
			part.CollisionGroup = globals.DebrisGroup
		end
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
			if not db then
				db = true
				task.delay(debounceTime, function()
					db = false
				end)
				ClickByScreen(input.Position)
			end
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
		else
			toggleButton.Locked.Visible = true
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
