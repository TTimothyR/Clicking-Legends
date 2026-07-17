local PlaytimeHandler = {}
local db = false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Globals = require(ReplicatedStorage.Framework.Globals)
local InterfaceUtility = require(ReplicatedStorage.Framework.InterfaceUtility)
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local PlaytimeRewards = require(ReplicatedStorage.Framework.Library.PlaytimeRewards)
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncClient = require(script.Parent.DataSyncClient)

local rewardConnections: { RBXScriptConnection } = {}
local nextDailyReset = Globals.GetResetTime(Globals.DailyResetTime)
local gradientsToAnimate = {}
local currentRotation: { value: number } = { value = 0 }
local legendaryConnection: RBXScriptConnection = nil

local player: Player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local frames = playerGui:WaitForChild("Frames") :: ScreenGui
local dailyRewardsFrame = frames:WaitForChild("DailyRewards") :: Frame
local templates = dailyRewardsFrame:WaitForChild("Templates") :: Folder
local dayTemplate = templates:WaitForChild("DayTemplate") :: Frame
local mainDaily = dailyRewardsFrame:WaitForChild("Main") :: Frame
local dailyHolder = mainDaily:WaitForChild("Holder") :: Frame
local nextRewardTimer = mainDaily:WaitForChild("NextRewardTimer") :: TextLabel
local streakFrame = mainDaily:WaitForChild("StreakFrame") :: Frame

local function UpdateClaimButton(color: string, text: string, button)
	button.Frame.UIGradient.Color = Globals.ButtonPresets[color].Gradient
	button.Frame.UIStroke.Color = Globals.ButtonPresets[color].StrokeColor
	button.Title.UIStroke.Color = Globals.ButtonPresets[color].StrokeColor
	button.Title.Text = text
end

local function UpdateDisplay(textLabel, endTime)
	local remaining = endTime - os.time()
	if remaining <= 0 then
		textLabel.Text = "Claim!"
		UpdateClaimButton("Green", "Claim!", textLabel.Parent)
	else
		textLabel.Text = Globals.FormatTime(remaining, true)
	end
end

local function GetStartDay(dailyRewards): number
	local minimum: number = math.huge
	for day: string, data in pairs(dailyRewards) do
		local dayNumber = tonumber((day:gsub("Day", ""))) :: number
		if dayNumber < minimum and not data.Claimed then
			minimum = dayNumber
		end
	end
	return minimum
end

local function LoadRewardFrame(rewardInstance: any, rewardData: PlaytimeRewards.Reward)
	rewardInstance.Frame.Frame.Icon.Image = ImageService[rewardData.Name] or ImageService["Placeholder"]
	rewardInstance.Frame.Amount.Text = (rewardData.Amount == 1) and "" or "x" .. rewardData.Amount

	if rewardData.Amount == 1 then
		rewardInstance.Frame.Amount.Visible = false
	end
	rewardInstance.Frame.PotionName.Visible = (rewardData.Category == "Potions")

	if rewardData.Category == "Potions" then
		rewardInstance.Frame.PotionName.Text = string.gsub(rewardData.Name, "_", " ")
	end

	local rarity = PlaytimeRewards.GetItemRarity[rewardData.Category](rewardData.Name)
	rewardInstance.Frame.BackgroundColor3 = Globals.RarityColors[rarity]

	if rarity == "Legendary" then
		rewardInstance.Frame.Legendary.Enabled = true
		rewardInstance.Glow.Legendary.Enabled = true
	end
end

local function LoadDayFrame(count: number, startDay: number, dayData)
	local day: number = startDay + count
	local clone = dayTemplate:Clone() :: Frame
	clone.Name = "Day" .. day
	clone.Parent = dailyHolder
	clone.LayoutOrder = count

	local startPosition: UDim2 = UDim2.fromScale(0.132, 0.494)
	local padding: UDim2 = UDim2.fromScale(clone.Size.X.Scale + 0, 0)

	local xPosition = startPosition.X.Scale + (padding.X.Scale * count)
	clone.Position = UDim2.fromScale(xPosition, startPosition.Y.Scale)

	clone.DayNumber.Text = "Day " .. day
	local colorPreset = ""

	local timerConnection = nil
	local clickConnection = nil

	local claimButton = clone.ClaimButton :: ImageButton

	if dayData.Active then
		if dayData.EndTime > os.time() then
			colorPreset = "Orange"
			timerConnection = RunService.Heartbeat:Connect(function(_: number)
				UpdateDisplay(claimButton.Title, dayData.EndTime)
			end) :: RBXScriptConnection
		else
			colorPreset = "Green"
			claimButton.Title.Text = "Claim!"
		end
	else
		colorPreset = "Red"
		claimButton.Title.Text = "Unavailable"
	end

	clickConnection = claimButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)

			local success = Network:InvokeServer("ClaimDailyReward", day)
			if not success then
				return
			end

			local animationTime = 0.25
			clone:TweenSize(UDim2.fromScale(0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, animationTime)
			task.delay(animationTime, function()
				clone:Destroy()
			end)

			for _, instance: Instance in ipairs(dailyHolder:GetChildren()) do
				if instance:IsA("Frame") and instance ~= clone then
					instance.LayoutOrder -= 1

					local newX = startPosition.X.Scale + (padding.X.Scale * instance.LayoutOrder)
					instance:TweenPosition(
						UDim2.fromScale(newX, startPosition.Y.Scale),
						Enum.EasingDirection.Out,
						Enum.EasingStyle.Sine,
						animationTime
					)
				end
			end
			task.wait(animationTime)
			PlaytimeHandler.LoadDailyRewards()
		end
	end)

	clone:GetPropertyChangedSignal("Parent"):Once(function()
		if timerConnection and timerConnection.Connected then
			timerConnection:Disconnect()
		end
		if clickConnection and clickConnection.Connected then
			clickConnection:Disconnect()
		end
	end)

	table.insert(rewardConnections, timerConnection)
	table.insert(rewardConnections, clickConnection)

	LoadRewardFrame(clone.RewardTemplate, dayData.Reward)
	UpdateClaimButton(colorPreset, claimButton.Title.Text, claimButton)
	clone.Visible = true
end

function PlaytimeHandler.LoadDailyRewards()
	local dailyRewards = DataSyncClient.Get("DailyRewards")
	local dailyStreak = DataSyncClient.Get("DailyStreak")

	for _, child: Instance in pairs(dailyHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, connection: RBXScriptConnection in pairs(rewardConnections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(rewardConnections)

	local resetTimer = RunService.Heartbeat:Connect(function(_: number)
		local remaining = nextDailyReset - os.time()
		if remaining > 0 then
			nextRewardTimer.Text = Globals.FormatTime(remaining, false)
		end
	end) :: RBXScriptConnection
	table.insert(rewardConnections, resetTimer)

	streakFrame.StreakAmount.Text = (dailyStreak == 1) and string.format("🔥 %s Day", dailyStreak)
		or string.format("🔥 %s Days", dailyStreak)

	local startDay: number = GetStartDay(dailyRewards)

	for i = 0, 5, 1 do
		LoadDayFrame(i, startDay, dailyRewards["Day" .. (startDay + i)])
	end

	-- Globals.GetAnimatedGradients({ dailyHolder }, gradientsToAnimate)
	for _, child in ipairs(dailyHolder:GetChildren()) do
		if child:IsA("Frame") then
			if child.RewardTemplate.Glow.Legendary.Enabled then
				table.insert(gradientsToAnimate, child.RewardTemplate.Glow.Legendary)
			end
			if child.RewardTemplate.Frame.Legendary.Enabled then
				table.insert(gradientsToAnimate, child.RewardTemplate.Frame.Legendary)
			end
		end
	end

	legendaryConnection =
		InterfaceUtility.CreateGradientAnimation(gradientsToAnimate, currentRotation) :: RBXScriptConnection
	table.insert(rewardConnections, legendaryConnection)
end

function PlaytimeHandler.UpdateDayResetTimer()
	nextDailyReset = Globals.GetResetTime(Globals.DailyResetTime)
	PlaytimeHandler.LoadDailyRewards()
end

function PlaytimeHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	dailyRewardsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if dailyRewardsFrame.Visible == false then
			if legendaryConnection.Connected then
				legendaryConnection:Disconnect()
				table.clear(gradientsToAnimate)
			end
		end
	end)
end

return PlaytimeHandler
