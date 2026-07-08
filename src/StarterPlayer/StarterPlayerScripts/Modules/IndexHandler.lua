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
local claimButton = rewardFrame:WaitForChild("Claim") :: ImageButton

-- Modules
local InfiniteMath = require(ReplicatedStorage.Framework.InfiniteMath)
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
		if child:IsA("ImageButton") and child.Name ~= "Claim" then
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

		local clone = rewardTemplate:Clone() :: ImageButton
		clone.Icon.Image = ImageService[rewardName] or ImageService["Placeholder"]
		clone.Amount.Text = "x" .. InfiniteMath.new(amount):GetSuffix(true)

		clone.Parent = rewardFrame
		clone.Visible = true
	end
end

local function LoadPets(index, eggName: string, shiny: boolean)
	for _, child in ipairs(petHolder:GetChildren()) do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	for pet, data in pairs(eggStats[eggName].Pets) do
		local clone = petTemplate:Clone()
		clone.Name = pet
		clone.Parent = petHolder
		clone.LayoutOrder = data[2]

		local fullName = shiny and "Shiny " .. pet or pet
		clone.Frame.Icon.Image = ImageService[fullName] or ImageService["Placeholder"]

		local rarity = petStats[pet].Rarity
		clone.Frame.BackgroundColor3 = globals.RarityColors[rarity]
		if rarity == "Legendary" then
			clone.Glow.Visible = true
			clone.Frame.Legendary.Enabled = true
		end

		if not shiny then
			if not index[pet] then
				clone.Frame.Icon.ImageColor3 = Color3.fromRGB(0, 0, 0)
			end
		else
			if not index["Shiny " .. pet] then
				clone.Frame.Icon.ImageColor3 = Color3.fromRGB(0, 0, 0)
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
	lockedFrame.Visible = visible
end

local function SelectEgg(eggName: string)
	local index = dataSync.Get("PetIndex")
	local claimedEggs = dataSync.Get("ClaimedEggs")
	selectedEgg = eggName

	local fullEggName = shinySelected and "Shiny " .. eggName or eggName

	if claimedEggs[fullEggName] then
		rewardFrame.Visible = false
	else
		rewardFrame.Visible = true
	end

	LoadPets(index, eggName, shinySelected)
	LoadRewards()

	miscFrame.Visible = true
end

function IndexHandler.LoadIndex()
	for _, child in ipairs(eggHolder:GetChildren()) do
		if child:IsA("ImageButton") then
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

			local infoFrame = clone.Frame
			local petsInEgg = eggPetCount[eggName]
			local normal, shiny = GetPlayerPetCount(eggName)

			infoFrame.EggName.Text = eggName
			infoFrame.LimitedTag.Visible = eggStats[eggName].Limited
			infoFrame.NormalCollected.Text = normal .. "/" .. petsInEgg
			infoFrame.ShinyCollected.Text = shiny .. "/" .. petsInEgg

			local clickCon = clone.MouseButton1Click:Connect(function()
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

	claimButton.MouseButton1Click:Connect(function()
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
