local EggHandler = {}

-- Services
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local ts = game:GetService("TweenService")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local eggOpens = workspace:WaitForChild("EggOpens")
local camera: Camera = workspace.CurrentCamera
local cameraOffset = CFrame.new(0, 0, -4.5) * CFrame.Angles(0, math.rad(180), 0)

local assets = rs:WaitForChild("Assets")
local petModels = assets:WaitForChild("PetModels")
local eggModels = assets:WaitForChild("EggModels")
local clickModels = assets:WaitForChild("ClickModels")
local sounds = assets:WaitForChild("Sounds")

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local secretAnimation = workspace:WaitForChild("SecretAnimation")
local technical: Model = secretAnimation:WaitForChild("Technical")
local ground = technical:WaitForChild("Ground")
local cameraPos = technical:WaitForChild("CameraPos")
local cursors: Folder = secretAnimation:WaitForChild("Cursors")

local rng = Random.new()

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HUD")
local hatchOverlay = playerGui:WaitForChild("HatchOverlay")
local blackOut = hatchOverlay:WaitForChild("Blackout")
local whiteOut = hatchOverlay:WaitForChild("Whiteout")
local left = hud:WaitForChild("Left")
local boost = hud:WaitForChild("Boost")
local autoClicker = hud:WaitForChild("AutoClicker")
local clickButton = hud:WaitForChild("Click")
local popUps = hud:WaitForChild("PopUps")

-- Modules
local petStats = require(library.PetStats)
local modelUtil = require(framework.ModelUtility)
local network = require(framework.Network)
local menuHandler = require(script.Parent.MenuHandler)
local soundHandler = require(script.Parent.SoundHandler)
local globals = require(framework.Globals)
local interfaceUtility = require(framework.InterfaceUtility)
local dataSync = require(script.Parent.DataSyncClient)
local upgrades = require(library.Upgrades)

-- Constants
local dir, style, animTime = Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.3
local closedFrame = nil

local function CalculatePositions(amount: number)
	local eggDataList = {}
	local eggSpacing = 3.5

	local maxCols
	if amount == 1 then
		maxCols = 1
	elseif amount == 2 or amount == 4 then
		maxCols = 2
	elseif amount == 3 or amount == 5 or amount == 6 then
		maxCols = 3
	elseif amount == 7 or amount == 8 then
		maxCols = 4
	elseif amount == 9 or amount == 10 then
		maxCols = 5
	elseif amount == 100 then
		maxCols = 10
	end

	local numRows = math.ceil(amount / maxCols)

	local zBase = 0
	local zDepthPerDimensionUnit = 0.7
	local maxVisibleDimension = math.max(maxCols, numRows)
	local dynamicFinalZ = zBase + (maxVisibleDimension - 1) * zDepthPerDimensionUnit

	for i = 1, amount do
		local idx = i - 1
		local col = idx % maxCols
		local row = math.floor(idx / maxCols)

		local currentEggsInThisRow = maxCols
		if row == numRows - 1 then
			local remainingEggs = amount % maxCols
			if remainingEggs ~= 0 then
				currentEggsInThisRow = remainingEggs
			end
		end

		local xOffset = (col - (currentEggsInThisRow - 1) / 2) * eggSpacing
		local yOffset = (row - (numRows - 1) / 2) * eggSpacing

		local initialPosValue = CFrame.new(xOffset, yOffset - 7, dynamicFinalZ)
		local finalPosValue = CFrame.new(xOffset, yOffset, dynamicFinalZ)

		table.insert(eggDataList, {
			pos0 = initialPosValue,
			pos1 = finalPosValue,
		})
	end

	return eggDataList
end

local function HideUI()
	left:TweenPosition(UDim2.fromScale(-0.25, 0.162), dir, style, animTime)
	autoClicker:TweenPosition(UDim2.fromScale(0.218, 1), dir, style, animTime)
	clickButton:TweenPosition(UDim2.fromScale(0.517, 1.2), dir, style, animTime)
	boost:TweenPosition(UDim2.fromScale(0.292, -0.3), dir, style, animTime)
	popUps.Visible = false

	if menuHandler.activeFrame then
		closedFrame = menuHandler.activeFrame
		menuHandler.closeFrame(closedFrame)
	end
end

local function UnHideUI()
	left:TweenPosition(UDim2.fromScale(0.006, 0.162), dir, style, animTime)
	autoClicker:TweenPosition(UDim2.fromScale(0.218, 0.891), dir, style, animTime)
	clickButton:TweenPosition(UDim2.fromScale(0.517, 0.91), dir, style, animTime)
	boost:TweenPosition(UDim2.fromScale(0.292, 0.013), dir, style, animTime)
	popUps.Visible = true
	if closedFrame then
		menuHandler.openFrame(closedFrame)
		closedFrame = nil
	end
end

function EggHandler.EggAnimation(eggName: string, amount: number, petsData)
	local speed = 1
	local ownedGamepsses = dataSync.Get("OwnedGamepasses")
	local upgradeLevels = dataSync.Get("UpgradeLevels")

	if ownedGamepsses["Fast Hatch"] then
		speed += 0.35
	end
	speed += upgradeLevels["Faster Egg Open"] * (upgrades["Faster Egg Open"].Increment / 100)

	local eggData = {}
	local eggAnimationConnections = {}
	local eggDestroyConnections = {}
	local legendaries = 0
	local legendaryEggData = {}
	local secrets = 0
	local secretEggData = {}

	HideUI()

	for i = 1, amount do
		local egg: Model = eggModels:FindFirstChild(eggName):Clone()
		local attach = Instance.new("Attachment")
		attach.Parent = egg.PrimaryPart
		attach.Name = "Particle"

		local smoke: ParticleEmitter = script.Smoke:Clone()
		smoke.Parent = attach
		smoke.Name = "Smoke"

		local stats = petStats[petsData[i].petName]
		local rarity = stats and stats.Rarity or "Common"

		if rarity == "Legendary" then
			speed = 1
		end

		for _, particle: ParticleEmitter in ipairs(script.Confetti:GetChildren()) do
			local clone: ParticleEmitter = particle:Clone()
			clone.Parent = attach
			clone.Name = "Confetti"
		end

		local highlight: Highlight = Instance.new("Highlight")
		highlight.Parent = egg
		highlight.Enabled = false
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded

		smoke.Lifetime = NumberRange.new(smoke.Lifetime.Min / speed, smoke.Lifetime.Max / speed)

		local originalScale = egg:GetScale()
		egg.Parent = eggOpens
		egg:ScaleTo(0.00001)

		local pos = Instance.new("CFrameValue")
		local rot = Instance.new("CFrameValue")
		rot.Value = CFrame.Angles(0, 0, 0)

		local positions = CalculatePositions(amount)
		pos.Value = positions[i].pos1

		if stats.Secret then
			secrets += 1
		elseif rarity == "Legendary" then
			legendaries += 1
		end

		if stats.Secret or rarity == "Legendary" then
			highlight.Enabled = true
			local colorConnection = runService.Heartbeat:Connect(function()
				local t = tick() * 0.4 % 1
				local color = Color3.fromHSV(t, 0.55, 1)
				highlight.FillColor = color
				highlight.OutlineColor = color
			end)
			egg:GetPropertyChangedSignal("Parent"):Once(function()
				colorConnection:Disconnect()
			end)
		end

		table.insert(eggData, {
			egg = egg,
			petData = petsData[i],
			pos = pos,
			rot = rot,
			endScale = originalScale,
			endPos = positions[i].pos1,
			special = (rarity == "Legendary"),
			secret = stats.Secret,
		})

		local eggConnection: RBXScriptConnection = runService.RenderStepped:Connect(function(_)
			egg:PivotTo(camera.CFrame * cameraOffset * pos.Value * rot.Value)
		end)
		table.insert(eggAnimationConnections, eggConnection)

		local destroyConnection: RBXScriptConnection = egg:GetPropertyChangedSignal("Parent"):Once(function()
			eggConnection:Disconnect()
		end)
		table.insert(eggDestroyConnections, destroyConnection)
	end

	for _, data in ipairs(eggData) do
		task.spawn(function()
			modelUtil.AnimateScale(
				data.egg:GetScale(),
				data.endScale,
				TweenInfo.new(0.35 / speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				data.egg
			)
		end)
	end
	task.wait(0.65 / speed)

	if secrets > 0 then
		for _, data in ipairs(eggData) do
			if not data.secret then
				task.spawn(function()
					modelUtil.AnimateScale(
						data.egg:GetScale(),
						0.00001,
						TweenInfo.new(0.35 / speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						data.egg
					)
				end)
			else
				table.insert(secretEggData, data)
			end
		end
		local specialPosValues = CalculatePositions(secrets)
		for i, data in ipairs(secretEggData) do
			data.endPos = specialPosValues[i].pos1
		end
		eggData = secretEggData
		speed = 1
	elseif legendaries > 0 then
		for _, data in ipairs(eggData) do
			if not data.special then
				task.spawn(function()
					modelUtil.AnimateScale(
						data.egg:GetScale(),
						0.00001,
						TweenInfo.new(0.35 / speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						data.egg
					)
				end)
			else
				table.insert(legendaryEggData, data)
			end
		end
		local specialPosValues = CalculatePositions(legendaries)
		for i, data in ipairs(legendaryEggData) do
			data.endPos = specialPosValues[i].pos1
		end
		eggData = legendaryEggData
		speed = 1
	end

	if secrets > 0 then
		local adjustTweens = {}
		for _, data in ipairs(secretEggData) do
			table.insert(
				adjustTweens,
				ts:Create(
					data.pos,
					TweenInfo.new(0.4 / speed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{ Value = data.endPos }
				)
			)
		end
		for _, t in ipairs(adjustTweens) do
			t:Play()
		end
	elseif legendaries > 0 then
		local adjustTweens = {}
		for _, data in ipairs(legendaryEggData) do
			table.insert(
				adjustTweens,
				ts:Create(
					data.pos,
					TweenInfo.new(0.4 / speed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{ Value = data.endPos }
				)
			)
		end
		for _, t in ipairs(adjustTweens) do
			t:Play()
		end
	end

	local startWait, endWait, direction, alpha = 0.5 / speed, 0.01 / speed, 1, 30
	local currentWait = startWait

	repeat
		local hatchTweens = {}
		for _, data in ipairs(eggData) do
			table.insert(hatchTweens, function()
				ts
					:Create(
						data.rot,
						TweenInfo.new(currentWait, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						{ Value = CFrame.Angles(0, 0, direction * math.rad(alpha)) }
					)
					:Play()
			end)
		end

		for _, func in ipairs(hatchTweens) do
			func()
		end
		soundHandler.PlaySound(sounds.Turn)
		task.wait(currentWait)
		currentWait /= 1.25
		direction *= -1
	until currentWait <= endWait

	for _, data in ipairs(eggData) do
		for _, descendant in ipairs(data.egg:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			end
		end
	end

	if secrets > 0 then
		local cursorAmount = 50

		soundHandler.PlaySound(sounds.Blackout)
		blackOut.BackgroundTransparency = 0
		blackOut.Visible = true

		camera.FieldOfView = 100
		task.wait(1)

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cameraPos.CFrame

		for _ = 1, cursorAmount do
			task.spawn(function()
				local clone: Model = clickModels.GoldenClick:Clone()
				clone.Parent = cursors

				local randomX = (rng:NextNumber() - 0.5) * 75
				local randomZ = (rng:NextNumber() - 0.5) * 75
				local yPos = ground.Size.Y / 2

				local worldCFrame = ground.CFrame * CFrame.new(randomX, yPos, randomZ)

				clone:PivotTo(worldCFrame)
			end)
		end

		local blackOutFade = ts:Create(
			blackOut,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		blackOutFade:Play()
		blackOutFade.Completed:Wait()

		local newEggModel: Model = eggModels[eggName]:Clone()
		local pos = Instance.new("CFrameValue")
		local size = newEggModel:GetExtentsSize()
		local cframe, _ = newEggModel:GetBoundingBox()

		local highlight: Highlight = Instance.new("Highlight")
		highlight.Parent = newEggModel
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Color3.fromRGB(255, 255, 255)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1

		local effectPart = Instance.new("Part")
		effectPart.Parent = newEggModel
		effectPart.Name = "Effect"
		effectPart.Anchored = true
		effectPart.Transparency = 1
		effectPart.CanCollide = false
		effectPart.CFrame = cframe
		effectPart.Size = size
		local splat: ParticleEmitter = script.Splat:Clone()
		splat.Parent = effectPart

		local primaryPart = newEggModel.PrimaryPart
		primaryPart.CFrame -= Vector3.new(0, size.Y / 2, 0)
		local endPos = CFrame.new(ground.CFrame.X, ground.CFrame.Y + ground.Size.Y / 2, ground.CFrame.Z)
		local startPos = CFrame.new(endPos.X, endPos.Y + 30, endPos.Z)
		pos.Value = startPos

		newEggModel.Parent = secretAnimation

		local eggConnection: RBXScriptConnection
		eggConnection = runService.RenderStepped:Connect(function(_)
			newEggModel:PivotTo(pos.Value)
		end)

		local eggDrop =
			ts:Create(pos, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = endPos })
		soundHandler.PlaySound(sounds.Impact)
		eggDrop:Play()
		eggDrop.Completed:Wait()

		interfaceUtility.ShakeCamera(camera, 0.2, 0.01, 10)

		for _, model in ipairs(cursors:GetChildren()) do
			task.spawn(function()
				local newCFrame = CFrame.new(model:GetPivot() * Vector3.new(0, rng:NextInteger(3, 10), 0))

				ts:Create(model.PrimaryPart, TweenInfo.new(0.5), { CFrame = newCFrame }):Play()
			end)
		end

		task.wait(0.5)

		for _, model in ipairs(cursors:GetChildren()) do
			task.spawn(function()
				local lookAt = CFrame.lookAt(model.PrimaryPart.Position, newEggModel:GetPivot().Position)

				ts:Create(model.PrimaryPart, TweenInfo.new(0.5), { CFrame = lookAt * CFrame.Angles(0, 2.6415, 0) }):Play()
			end)
		end

		task.wait(0.5)

		local waitTime = 0.25
		local startAngle = cameraPos.CFrame.Rotation.X

		for i, model in ipairs(cursors:GetChildren()) do
			if i == cursorAmount - 26 then
				local targetCameraCFrame = camera.CFrame - Vector3.new(0, 0, 5)
				ts:Create(camera, TweenInfo.new(0.45), { CFrame = targetCameraCFrame }):Play()
				ts
					:Create(highlight, TweenInfo.new(0.55), {
						FillTransparency = 0,
						OutlineTransparency = 0,
					})
					:Play()
			end
			if i == cursorAmount - 5 then
				local targetCameraCFrame = camera.CFrame + Vector3.new(0, 0, 10)
				ts:Create(camera, TweenInfo.new(0.35), { CFrame = targetCameraCFrame }):Play()
				ts:Create(whiteOut, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
			end
			local targetCFrame = newEggModel:GetPivot() + Vector3.new(0, size.Y / 2, 0)

			local go = ts:Create(model.PrimaryPart, TweenInfo.new(waitTime), { CFrame = targetCFrame })
			go:Play()
			go.Completed:Wait()
			soundHandler.PlaySound(sounds.Click)
			camera.CFrame *= CFrame.Angles(startAngle / cursorAmount, 0, 0)
			splat:Emit(50)
			modelUtil.AnimateScale(newEggModel:GetScale(), newEggModel:GetScale() + 0.05, TweenInfo.new(waitTime), newEggModel)
			waitTime /= 1.04
			model:Destroy()
		end
		camera.FieldOfView = 70
		camera.CameraType = Enum.CameraType.Custom
		task.wait(1)
		ts:Create(whiteOut, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		newEggModel:Destroy()
		eggConnection:Disconnect()
	end

	for _, data in ipairs(eggData) do
		runService.Heartbeat:Wait()
		if legendaries > 0 or secrets > 0 then
			for _, particle: ParticleEmitter in ipairs(data.egg.PrimaryPart.Particle:GetChildren()) do
				if particle.Name == "Confetti" then
					particle:Emit(40)
				else
					particle:Emit(17)
				end
			end
		end
		data.egg.PrimaryPart.Particle.Smoke:Emit(17)
	end

	local petData = {}
	local petAnimationConnections = {}
	local petUIConnections = {}
	local petDestroyConnections = {}

	if legendaries > 0 or secrets > 0 then
		soundHandler.PlaySound(sounds.Legendary)
	else
		soundHandler.PlaySound(sounds.Normal)
	end

	for _, data in ipairs(eggData) do
		local activePetData = data.petData
		local petName: string = activePetData.fullName

		if activePetData.shiny and not petModels:FindFirstChild(petName) then
			warn("Shiny model for pet", petName, "not found, falling back to regular model.")
			petName = activePetData.petName
		end
		if not petModels:FindFirstChild(petName) then
			warn("Model for pet", petName, "not found, falling back to Doggy.")
			petName = "Doggy"
		end

		local pet: Model = petModels:FindFirstChild(petName):Clone()
		pet.Parent = eggOpens

		local petPos = Instance.new("CFrameValue")
		local petRot = Instance.new("CFrameValue")

		petPos.Value = data.endPos * CFrame.new(0, 0, 2)
		petRot.Value = CFrame.Angles(0, 0, 0)

		local nameLabel: TextLabel = script.PetName:Clone()
		nameLabel.Name = petName
		nameLabel.Text = petName
		nameLabel.Parent = hatchOverlay
		nameLabel.Visible = true

		local rarityLabel: TextLabel = script.Rarity:Clone()
		rarityLabel.Name = activePetData.rarity
		rarityLabel.Text = activePetData.rarity
		rarityLabel.TextColor3 = globals.RarityColors[activePetData.rarity]
		rarityLabel.Parent = hatchOverlay
		rarityLabel.Visible = true

		if activePetData.rarity == "Legendary" then
			local colorConnection = runService.Heartbeat:Connect(function()
				local t = tick() * 0.4 % 1
				local color = Color3.fromHSV(t, 0.55, 1)
				rarityLabel.TextColor3 = color
			end)
			pet:GetPropertyChangedSignal("Parent"):Once(function()
				colorConnection:Disconnect()
			end)
		end

		local miscLabel: TextLabel = script.Misc:Clone()
		miscLabel.Text = ""
		miscLabel.Parent = hatchOverlay
		miscLabel.Visible = true

		if activePetData.autoDeleted then
			miscLabel.Text = "Auto Deleted"
		elseif activePetData.new then
			miscLabel.Text = "New Pet Discovered!"
		end

		table.insert(petData, {
			pet = pet,
			pos = petPos,
			rot = petRot,
			endPos = data.endPos,
			nameLabel = nameLabel,
			rarityLabel = rarityLabel,
			miscLabel = miscLabel,
		})

		local petConnection: RBXScriptConnection = runService.RenderStepped:Connect(function(_)
			pet:PivotTo(
				CFrame.new((camera.CFrame * cameraOffset * petPos.Value).Position, camera.CFrame.Position) * petRot.Value
			)
		end)
		table.insert(petAnimationConnections, petConnection)

		local primaryPart = pet.PrimaryPart
		local uiConnection: RBXScriptConnection = runService.Heartbeat:Connect(function(_)
			local screenPoint, onScreen =
				camera:WorldToScreenPoint(primaryPart.Position - primaryPart.CFrame.UpVector * primaryPart.Size.Y / 2)
			nameLabel.Visible = onScreen
			rarityLabel.Visible = onScreen
			miscLabel.Visible = onScreen

			if onScreen then
				nameLabel.Position =
					UDim2.fromScale(screenPoint.X / camera.ViewportSize.X, (screenPoint.Y + 100) / camera.ViewportSize.Y)
				rarityLabel.Position =
					UDim2.fromScale(screenPoint.X / camera.ViewportSize.X, (screenPoint.Y + 150) / camera.ViewportSize.Y)
				miscLabel.Position =
					UDim2.fromScale(screenPoint.X / camera.ViewportSize.X, (screenPoint.Y - 100) / camera.ViewportSize.Y)
			end
		end)
		table.insert(petUIConnections, uiConnection)

		local petDestroyConnection: RBXScriptConnection = pet:GetPropertyChangedSignal("Parent"):Once(function()
			petConnection:Disconnect()
		end)
		table.insert(petDestroyConnections, petDestroyConnection)
	end
	for _, data in ipairs(eggData) do
		if legendaries > 0 then
			task.delay(data.egg.PrimaryPart.Particle.Confetti.Lifetime.Max, function()
				data.egg:Destroy()
			end)
		else
			task.delay(data.egg.PrimaryPart.Particle.Smoke.Lifetime.Max, function()
				data.egg:Destroy()
			end)
		end
	end

	task.wait(1.85 / speed)
	for _, data in ipairs(petData) do
		data.nameLabel:Destroy()
		data.rarityLabel:Destroy()
		data.miscLabel:Destroy()
	end

	local removeTweens = {}
	local removeTime = 0.75 / speed

	for _, data in ipairs(petData) do
		table.insert(removeTweens, function()
			modelUtil.AnimateScale(
				data.pet:GetScale(),
				0.00001,
				TweenInfo.new(removeTime, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				data.pet
			)
			for _, descendant in ipairs(data.pet:GetDescendants()) do
				if descendant:IsA("BasePart") then
					ts
						:Create(
							descendant,
							TweenInfo.new(removeTime * 1.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
							{ Transparency = 1 }
						)
						:Play()
				end
			end
		end)
	end
	for _, func in ipairs(removeTweens) do
		task.spawn(func)
	end
	task.wait(removeTime)
	UnHideUI()

	for _, data in ipairs(petData) do
		data.pet:Destroy()
	end

	for _, con: RBXScriptConnection in ipairs(eggAnimationConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end
	for _, con: RBXScriptConnection in ipairs(eggDestroyConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end
	for _, con: RBXScriptConnection in ipairs(petAnimationConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end
	for _, con: RBXScriptConnection in ipairs(petUIConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end
	for _, con: RBXScriptConnection in ipairs(petDestroyConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end

	network:FireServer("ResetVariables")
end

return EggHandler
