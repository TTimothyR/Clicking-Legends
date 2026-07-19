local PrizeHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local selectedType = "Eggs"
local isLoaded = false

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local prizeFrame = frames:WaitForChild("Prizes")
local templates = prizeFrame:WaitForChild("Templates")
local prizeTemplate = templates:WaitForChild("PrizeTemplate")
local buttonsFrame = prizeFrame:WaitForChild("Buttons")
local eggsButton = buttonsFrame:WaitForChild("Eggs")
local clicksButton = buttonsFrame:WaitForChild("Clicks")
local main = prizeFrame:WaitForChild("Main")
local holderFrame = main:WaitForChild("Holder")
local scrollingHolder = holderFrame:WaitForChild("ScrollingFrame")

-- Modules
local prizes = require(library.Prizes)
local infMath = require(framework.InfiniteMath)
local network = require(framework.Network)
local dataSync = require(script.Parent.DataSyncClient)

-- Constants
local rewardFormat = {
	Pet = function(data)
		local fullName = data[3] and "Shiny " .. data[2] or data[2]
		return fullName
	end,
	Currency = function(data)
		return infMath.new(data[3]):GetSuffix(true) .. " " .. data[2]
	end,
	Perk = function(data)
		local perkFormat = {
			EggHatches = "+" .. data[3] .. " Egg Hatches",
			HatchSpeed = "+" .. data[3] .. "% Hatch Speed",
			LuckPercentage = "+" .. data[3] .. "% Luck",
			ClickMultiplier = "+" .. data[3] .. "% Click Multiplier",
		}
		return perkFormat[data[2]] or "N/A"
	end,
}

local function IsPrizeClaimed(prizeData, prizeIndex)
	for _, idx in ipairs(prizeData) do
		if idx == prizeIndex then
			return true
		end
	end
	return false
end

local function UpdatePrizeProgress(clone, targetType: string, data, claimedPrizes)
	if targetType ~= "Eggs" and targetType ~= "ActualClicks" then
		return
	end
	local claimed: boolean = IsPrizeClaimed(claimedPrizes[targetType], tonumber(clone.Name))

	local target = infMath.new(data.Target)
	local goal: string = (targetType == "Eggs") and "Hatch " .. target:GetSuffix(true) .. " Eggs"
		or "Click " .. target:GetSuffix(true) .. " Times"
	clone.Task.Text = goal

	local currentProgress = infMath.new(dataSync.Get(targetType))
	local procentualProgress = infMath.new(currentProgress / target):GetSuffix(true)

	clone.Progress.Level.Text = (currentProgress < target)
			and currentProgress:GetSuffix(true) .. " / " .. target:GetSuffix(true)
		or "Completed"
	local number = tonumber(procentualProgress) or 0
	clone.Progress.Frame.Size = UDim2.fromScale(math.min(number, 1), 1)

	local rewardLabel = clone.Reward
	local rewardData = data.Reward

	local func = rewardFormat[rewardData[1]]
	rewardLabel.Text = func and "Reward: " .. func(rewardData) or "Reward: N/A"

	clone.Accept.CantClaim.Visible = (currentProgress < target)
	if claimed then
		clone.Accept.Title.Text = "Claimed"
		clone.Accept.CantClaim.Visible = true
	end
end

local function UpdatePrizes()
	if not isLoaded then
		return
	end
	for i, data in ipairs(prizes[selectedType]) do
		local clone: Frame = scrollingHolder:FindFirstChild(i)

		UpdatePrizeProgress(clone, selectedType, data, dataSync.Get("ClaimedPrizes"))
	end
end

function PrizeHandler.LoadPrizes(targetType: string)
	targetType = targetType or selectedType

	for _, instance in ipairs(scrollingHolder:GetChildren()) do
		if instance:IsA("Frame") then
			instance:Destroy()
		end
	end

	for i, data in ipairs(prizes[targetType]) do
		local clone = prizeTemplate:Clone()
		clone.Parent = scrollingHolder
		clone.LayoutOrder = i
		clone.Name = i

		UpdatePrizeProgress(clone, targetType, data, dataSync.Get("ClaimedPrizes"))

		local clickConnection: RBXScriptConnection
		clickConnection = clone.Accept.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				local warning = network:InvokeServer("ClaimPrize", targetType, tonumber(clone.Name))
				if warning then
					warn(warning)
				end
			end
		end)
		clone:GetPropertyChangedSignal("Parent"):Once(function()
			clickConnection:Disconnect()
		end)

		clone.Visible = true
	end
	isLoaded = true
end

function PrizeHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	eggsButton.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if selectedType ~= "Eggs" then
				selectedType = "Eggs"
				PrizeHandler.LoadPrizes(selectedType)
			end
		end
	end)
	clicksButton.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if selectedType ~= "ActualClicks" then
				selectedType = "ActualClicks"
				PrizeHandler.LoadPrizes(selectedType)
			end
		end
	end)

	dataSync.OnChanged("ActualClicks", function()
		if selectedType == "ActualClicks" and prizeFrame.Visible then
			UpdatePrizes()
		end
	end)

	dataSync.OnChanged("Eggs", function()
		if selectedType == "Eggs" and prizeFrame.Visible then
			UpdatePrizes()
		end
	end)

	dataSync.OnChanged("ClaimedPrizes", function()
		UpdatePrizes()
	end)
end

return PrizeHandler
