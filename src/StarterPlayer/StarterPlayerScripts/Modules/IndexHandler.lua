local IndexHandler = {}
local db = false

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local clickConnections = {}
local animationConnections = {}
local shinySelected: boolean = false
local selectedEgg: string = nil

local eggPetCount = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local indexFrame = frames:WaitForChild("Index")
local templates = indexFrame:WaitForChild("Templates")
local eggTemplate = templates:WaitForChild("EggTemplate")
local petTemplate = templates:WaitForChild("PetTemplate")
local rewardTemplate = templates:WaitForChild("RewardTemplate")
local main = indexFrame:WaitForChild("Main")
local eggsFrame = main:WaitForChild("Eggs")
local eggHolder = eggsFrame:WaitForChild("EggHolder")
local petsFrame = main:WaitForChild("Pets")
local miscFrame = petsFrame:WaitForChild("ScrollingFrame")
local petHolder = miscFrame:WaitForChild("PetHolder")
local buttons = miscFrame:WaitForChild("Buttons")
local normalButton = buttons:WaitForChild("Normal")
local shinyButton = buttons:WaitForChild("Shiny")
local discoveryFrame = miscFrame:WaitForChild("Discovery")
local lockedFrame = discoveryFrame:WaitForChild("Locked")
local rewardFrame = discoveryFrame:WaitForChild("RewardFrame")
local claimButton = rewardFrame:WaitForChild("Claim") :: Frame

-- Modules
local InfiniteMath = require(ReplicatedStorage.Framework.InfiniteMath)
local InterfaceUtility = require(ReplicatedStorage.Framework.InterfaceUtility)
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local globals = require(framework.Globals)
local network = require(framework.Network)
local eggStats = require(library.EggStats)
local petStats = require(library.PetStats)
local dataSync = require(script.Parent.DataSyncClient)

local function LoadTotalPetCount()
	for eggName, data in pairs(eggStats) do
		local count = 0
		for _, _ in pairs(data.Pets) do
			count += 1
		end
		eggPetCount[eggName] = count
	end
end

local function GetPlayerPetCount(eggName: string)
	local index = dataSync.Get("PetIndex")

	local normalCount = 0
	local shinyCount = 0
	for pet, _ in pairs(eggStats[eggName].Pets) do
		if index[pet] then
			normalCount += 1
		end
		if index["Shiny " .. pet] then
			shinyCount += 1
		end
	end

	return normalCount, shinyCount
end

local function LoadRewards()
	for _, child in ipairs(rewardFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Claim" then
			child:Destroy()
		end
	end

	local rewardTable = shinySelected and eggStats[selectedEgg].ShinyRewards or eggStats[selectedEgg].Rewards

	if not rewardTable then
		return
	end
	for _, rewardData in ipairs(rewardTable) do
		local rewardName = rewardData[2]
		local amount = rewardData[3]

		local clone = rewardTemplate:Clone() :: Frame
		clone.Click.Icon.Image = ImageService[rewardName] or ImageService["Placeholder"]
		clone.Click.Amount.Text = "x" .. InfiniteMath.new(amount):GetSuffix(true)

		clone.Parent = rewardFrame
		clone.Visible = true
	end
end

local function LoadPets(index, eggName: string, shiny: boolean)
	for _, child in ipairs(petHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, connection in ipairs(animationConnections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(animationConnections)

	for pet, data in pairs(eggStats[eggName].Pets) do
		local clone = petTemplate:Clone()
		clone.Name = pet
		clone.Parent = petHolder
		clone.LayoutOrder = data[2]

		local fullName = shiny and "Shiny " .. pet or pet
		local chance = data[1] / (shiny and globals.ShinyChance or 1)
		local chanceDisplay = nil

		local newFrame = clone.Click

		if chance <= 0 then
			chanceDisplay = 0
		else
			if chance <= 0.001 then
				chanceDisplay =
					`<stroke color="#00295E" joins="miter" thickness="2"><font size="11">1</font>/{InfiniteMath.new(100 / chance)
						:GetSuffix(true)}</stroke>`
			else
				chanceDisplay = `{chance}%`
			end
		end

		newFrame.Frame.Icon.Image = ImageService[fullName] or ImageService["Placeholder"]
		newFrame.Frame.Chance.Text = chanceDisplay

		local rarity = petStats[pet].Rarity

		if shiny then
			newFrame.Glow.Visible = true
			newFrame.Glow.Shiny.Enabled = true
			newFrame.Frame.Shiny.Enabled = true
			newFrame.Frame.Frame.Normal.Enabled = false
			newFrame.Frame.Frame.Shiny.Enabled = true
			newFrame.Frame.Icon.ShinyEffect.Visible = true
			newFrame.Frame.Chance.Shiny.Enabled = true

			table.insert(animationConnections, InterfaceUtility.CreateShinyEffect(newFrame))
		else
			newFrame.Frame.Chance.TextColor3 = globals.RarityColors[rarity]
			if rarity == "Legendary" then
				newFrame.Frame.Chance.Legendary.Enabled = true
				newFrame.Glow.Visible = true
				newFrame.Glow.Legendary.Enabled = true
				newFrame.Frame.Legendary.Enabled = true
			else
				newFrame.Frame.BackgroundColor3 = globals.RarityColors[rarity]
			end
		end

		if not shiny then
			if not index[pet] then
				newFrame.Frame.Icon.ImageColor3 = Color3.fromRGB(0, 0, 0)
			end
		else
			if not index["Shiny " .. pet] then
				newFrame.Frame.Icon.ImageColor3 = Color3.fromRGB(0, 0, 0)
			end
		end

		clone.Visible = true
	end

	local petsInEgg = eggPetCount[eggName]
	local normalCount, shinyCount = GetPlayerPetCount(eggName)

	local visible = shiny and (shinyCount ~= petsInEgg) or (normalCount ~= petsInEgg)
	if visible then
		lockedFrame.Amount.Text = "Discover " .. petsInEgg .. " Pets!"
		local progress = shiny and shinyCount or normalCount
		lockedFrame.XP.Progress.Text = progress .. "/" .. petsInEgg
	end

	local fullEggName = shinySelected and "Shiny " .. eggName or eggName
	if not dataSync.Get("ClaimedEggs")[fullEggName] and not visible then
		rewardFrame.Visible = true
	end
	lockedFrame.Visible = visible
end

local function SelectEgg(eggName: string)
	local index = dataSync.Get("PetIndex")
	local claimedEggs = dataSync.Get("ClaimedEggs")
	selectedEgg = eggName

	local fullEggName = shinySelected and "Shiny " .. eggName or eggName

	if claimedEggs[fullEggName] then
		lockedFrame.Visible = false
	else
		lockedFrame.Visible = true
	end
	rewardFrame.Visible = false

	LoadPets(index, eggName, shinySelected)
	LoadRewards()

	miscFrame.Visible = true
end

function IndexHandler.LoadIndex()
	for _, child in ipairs(eggHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, con: RBXScriptConnection in ipairs(clickConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end

	task.spawn(function()
		for eggName, _ in pairs(eggStats) do
			local clone = eggTemplate:Clone()
			clone.Name = eggName
			clone.Parent = eggHolder
			clone.LayoutOrder = eggStats[eggName].LayoutOrder

			local infoFrame = clone.Click.Frame
			local petsInEgg = eggPetCount[eggName]
			local normal, shiny = GetPlayerPetCount(eggName)

			infoFrame.EggName.Text = eggName
			infoFrame.LimitedTag.Visible = eggStats[eggName].Limited
			infoFrame.NormalCollected.Text = normal .. "/" .. petsInEgg
			infoFrame.ShinyCollected.Text = shiny .. "/" .. petsInEgg
			infoFrame.EggIcon.Image = ImageService[eggName] or ImageService.Placeholder

			local clickCon = clone.Click.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					SelectEgg(eggName)
				end
			end)
			table.insert(clickConnections, clickCon)

			clone.Visible = true
		end
	end)

	if selectedEgg then
		SelectEgg(selectedEgg)
	end
end

function IndexHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	LoadTotalPetCount()

	normalButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			shinySelected = false
			if selectedEgg then
				SelectEgg(selectedEgg)
			end
		end
	end)
	shinyButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			shinySelected = true
			if selectedEgg then
				SelectEgg(selectedEgg)
			end
		end
	end)

	claimButton.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)

			local success = network:InvokeServer("ClaimIndexReward", selectedEgg, shinySelected)

			if success then
				rewardFrame.Visible = false
			end
		end
	end)
end

return IndexHandler
