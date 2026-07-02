local EggUIHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local eggs = workspace:WaitForChild("Eggs")

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local classes = rs:WaitForChild("Classes")
local assets = rs:WaitForChild("Assets")
local EggModels = assets.EggModels

local closestEgg2
local adornees = {}
local connections = {}
local maxDistance = 15
local autoHatching = false
local UnlockedEggs = {}

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local eggUI = assets:WaitForChild("EggUI")
local LockedEggUI = assets:WaitForChild("LockedEggUI")
local eggHolder = playerGui:WaitForChild("EggUI")
local frames = playerGui:WaitForChild("Frames")
local infoFrame = frames:WaitForChild("Info")

-- Modules
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local eggStats = require(library.EggStats)
local petStats = require(library.PetStats)
local network = require(framework.Network)
local globals = require(framework.Globals)
local dataSync = require(script.Parent.DataSyncClient)
local menuHandler = require(script.Parent.MenuHandler)
local infoClass = require(classes.InfoPopup)

local function SetupTemplate(ui)
	local petHolder = ui.Main.PetsFrame.Holder
	local buttons = ui.Main.Buttons

	local index = dataSync.Get("PetIndex")
	local luckPercentage = dataSync.Get("LuckPercentage")
	local gpsOwned = dataSync.Get("OwnedGamepasses")
	local luckPassOwned = gpsOwned["Double Luck"] and true or false

	local activePotions = dataSync.Get("ActivePotions")
	if activePotions["Lucky"] then
		local tier, data = next(activePotions["Lucky"].Active)

		if tier and data then
			luckPercentage += globals.GetPotionBuffAmount(tier, "Lucky")
		end
	end

	for _, item in ipairs(petHolder:GetChildren()) do
		if item:IsA("ImageButton") then
			local clickConnection: RBXScriptConnection

			local discovered = index[item.Name]

			-- local autoDeleted = network:InvokeServer('GetAutoDeleted', item.Name);
			local autoDeleted = dataSync.Get("AutoDeletedPets")

			if autoDeleted[item.Name] then
				item.Icon.ImageTransparency = 0.5
			else
				item.Icon.ImageTransparency = 0
			end

			if discovered then
				item.Icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end

			local chance = globals.GetPetChance(luckPassOwned, luckPercentage, item.Name, ui.Name, false)

			item.Chance.Text = globals.FormatChance(chance) .. "%"

			clickConnection = item.MouseButton1Click:Connect(function()
				if not db then
					db = true
					task.delay(0.15, function()
						db = false
					end)
					local newStatus = network:InvokeServer("ToggleAutoDelete", item.Name)
					if newStatus then
						item.Icon.ImageTransparency = 0.5
					else
						item.Icon.ImageTransparency = 0
					end
				end
			end)
			table.insert(connections[ui.Name], clickConnection)
		end
	end
	local singleConnection: RBXScriptConnection
	local multiConnection: RBXScriptConnection
	local autoConnection: RBXScriptConnection
	singleConnection = buttons.Hatch.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local egg = closestEgg2
			if egg ~= "" then
				network:FireServer("OpenEgg", egg, 1)
			end
		end
	end)
	multiConnection = buttons.Multi.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local egg = closestEgg2
			if egg ~= "" then
				network:FireServer("OpenEgg", egg, 3)
			end
		end
	end)
	autoConnection = buttons.Auto.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local egg = closestEgg2
			if egg ~= "" and not autoHatching then
				EggUIHandler.AutoHatch(egg)
			end
		end
	end)
	table.insert(connections[ui.Name], singleConnection)
	table.insert(connections[ui.Name], multiConnection)
	table.insert(connections[ui.Name], autoConnection)
end

local function GetClosestEgg()
	repeat
		task.wait()
	until #adornees == #eggHolder:GetChildren()

	runService.Heartbeat:Connect(function(_)
		local char = player.Character
		local humanoidRootPart = char and char:FindFirstChild("HumanoidRootPart")

		if not humanoidRootPart then
			return
		end

		local minDistance = math.huge
		local closestEgg1 = ""

		for i, data in ipairs(adornees) do
			local adornee = data.part
			local distance = (humanoidRootPart.Position - adornee.Position).Magnitude

			adornees[i].distance = distance

			if distance < minDistance then
				minDistance = distance
				closestEgg1 = adornee.Parent.Name
			end
		end

		if closestEgg1 ~= "" and minDistance <= maxDistance then
			closestEgg2 = closestEgg1
		else
			closestEgg2 = ""
		end
		local uiLock = player:FindFirstChild("UILock") :: BoolValue
		for _, ui in ipairs(eggHolder:GetChildren()) do
			local isLockedUI = ui.Name:sub(-6) == "Locked"
			local baseName = isLockedUI and ui.Name:sub(1, -7) or ui.Name

			if baseName == closestEgg2 and not uiLock.Value then
				if UnlockedEggs[baseName] then
					if isLockedUI then
						ui.Enabled = false
					else
						if not next(connections[baseName]) then
							SetupTemplate(ui)
						end
						ui.Enabled = true
					end
				else
					ui.Enabled = isLockedUI
				end
			else
				ui.Enabled = false
			end
		end

		for eggName, data in pairs(connections) do
			if eggHolder[eggName] and not eggHolder[eggName].Enabled then
				for i = #data, 1, -1 do
					data[i]:Disconnect()
					table.remove(data, i)
				end
			end
		end
	end)
end

local function ConfigureEggUI(egg: Model)
	local index = dataSync.Get("PetIndex")
	local clone = eggUI:Clone()
	local lockedClone = LockedEggUI:Clone()
	clone.Parent = eggHolder
	lockedClone.Parent = eggHolder

	local luckPercentage = dataSync.Get("LuckPercentage")
	local gpsOwned = dataSync.Get("OwnedGamepasses")
	local luckPassOwned = gpsOwned["Double Luck"] and true or false

	local activePotions = dataSync.Get("ActivePotions")
	if activePotions["Lucky"] then
		local tier, data = next(activePotions["Lucky"].Active)

		if tier and data then
			luckPercentage += globals.GetPotionBuffAmount(tier, "Lucky")
		end
	end

	clone.Adornee = egg:FindFirstChild("View")
	lockedClone.Adornee = egg:FindFirstChild("View")
	table.insert(adornees, {
		part = egg:FindFirstChild("View"),
		distance = math.huge,
	})

	lockedClone.Name = egg.Name .. "Locked"
	clone.Name = egg.Name

	local main = clone.Main
	local templates = main.Templates
	local petTemplate = templates.Pet
	local price = main.Price
	local eggName = main.EggName
	local petsFrame = main.PetsFrame
	local holder = petsFrame.Holder

	local currentStats = eggStats[egg.Name]
	eggName.EggName.Text = tostring(egg.Name)
	price.Amount.Text = currentStats.Price[2]

	local lockedMain = lockedClone.Main
	local Price = lockedMain.Price
	local Amount = Price.Amount
	local EggNameLabel = lockedMain.EggName

	Amount.Text = currentStats.Price[2]
	EggNameLabel.Text = tostring(egg.Name)

	for petName, data in pairs(currentStats.Pets) do
		local petClone = petTemplate:Clone()
		local chance = globals.GetPetChance(luckPassOwned, luckPercentage, petName, egg.Name, false)
		local rarity = petStats[petName].Rarity

		petClone.Parent = holder
		petClone.Name = petName

		petClone.Icon.Image = ImageService[petName] or ImageService["Placeholder"]

		petClone.Chance.Text = globals.FormatChance(chance) .. "%"
		petClone.Chance.TextColor3 = globals.RarityColors[rarity]
		if rarity == "Legendary" then
			local colorConnection = runService.Heartbeat:Connect(function()
				local t = tick() * 0.4 % 1
				local color = Color3.fromHSV(t, 0.55, 1)
				petClone.Chance.TextColor3 = color
			end)
			petClone:GetPropertyChangedSignal("Parent"):Once(function()
				colorConnection:Disconnect()
			end)
		end
		petClone.LayoutOrder = data[2]

		local discovered = index[petName]
		-- local autoDeleted = network:InvokeServer('GetAutoDeleted', petName);
		local autoDeleted = dataSync.Get("AutoDeletedPets")

		if autoDeleted[petName] then
			petClone.Icon.ImageTransparency = 0.5
		else
			petClone.Icon.ImageTransparency = 0
		end

		if not discovered then
			petClone.Icon.ImageColor3 = Color3.fromRGB(0, 0, 0)
		end
		petClone.Visible = true
	end
	connections[egg.Name] = {}
end

function EggUIHandler.AutoHatch(eggName: string)
	local success = network:InvokeServer("ToggleAutoHatch", eggName, true)

	if not success then
		infoClass.new("Hey!", "You have to join our group in order to use Auto Hatch!", function()
			menuHandler.handleOpenClose(infoFrame)
			local s, result = pcall(function()
				return GroupService:PromptJoinAsync(globals.GroupID)
			end)
			if s then
				if result == Enum.GroupMembershipStatus.Joined then
					infoClass.new("Hey!", "Thank you for joining the group! Perks are now granted.", function()
						menuHandler.handleOpenClose(infoFrame)
					end, infoFrame)
					menuHandler.handleOpenClose(infoFrame)
				end
			end
		end, infoFrame)
		menuHandler.handleOpenClose(infoFrame)
	end
	-- local egg = eggName;
	-- autoHatching = true;
	-- repeat
	--     network:InvokeServer('OpenEgg', egg, dataSync.Get('EggHatches'));
	--     task.wait(0.5);
	-- until closestEgg2 ~= egg;
	-- autoHatching = false;
end

function EggUIHandler.UnableToOpen(message: string)
	local previousFrame = menuHandler.activeFrame
	infoClass.new(nil, message, function()
		if previousFrame then
			menuHandler.handleOpenClose(previousFrame)
		else
			menuHandler.closeFrame(infoFrame)
		end
	end, infoFrame)

	menuHandler.handleOpenClose(infoFrame)
end

local function HatchComplete()
	if not autoHatching then
		return
	end
	network:FireServer("RequestNextHatch")
end

local function LoadEggModels()
	local UnlockedEggsData = dataSync.Get("UnlockedEggs")
	UnlockedEggs = UnlockedEggsData or {}

	for _, Egg in pairs(EggModels:GetChildren()) do
		local EggName = Egg.Name
		local EggInFolder = eggs:FindFirstChild(EggName)
		if not EggInFolder then
			continue
		end

		local Decor = EggInFolder.Decor :: Model
		local DarkGrey, LightGrey = Decor.DarkGrey :: Model, Decor.LightGrey :: Model
		local EggHolder: Part = LightGrey.EggHolder

		local EggModel: Model
		if not EggInFolder:FindFirstChild(EggName) then
			EggModel = EggModels:FindFirstChild(EggName):Clone()
			EggModel.Parent = EggInFolder
			EggModel:PivotTo(EggHolder.CFrame * CFrame.new(0, 3.8, 0))
			EggModel:ScaleTo(2.25)
		else
			EggModel = EggInFolder:FindFirstChild(EggName)
		end

		if not UnlockedEggsData[EggName] then
			for _, v in pairs(DarkGrey:GetChildren()) do
				v.Color = Color3.fromRGB(0, 0, 0)
			end
			for _, v in pairs(LightGrey:GetChildren()) do
				v.Color = Color3.fromRGB(0, 0, 0)
			end
			for _, v in pairs(EggModel:GetDescendants()) do
				if v:IsA("BasePart") then
					v.Color = Color3.fromRGB(0, 0, 0)
				end
			end
		else
			EggModel:Destroy()
			EggModel = EggModels:FindFirstChild(EggName):Clone()
			EggModel.Parent = EggInFolder
			EggModel:PivotTo(EggHolder.CFrame * CFrame.new(0, 3.8, 0))
			EggModel:ScaleTo(2.25)

			for _, v in pairs(DarkGrey:GetChildren()) do
				v.Color = Color3.fromRGB(85, 89, 99)
			end
			for _, v in pairs(LightGrey:GetChildren()) do
				v.Color = Color3.fromRGB(132, 139, 154)
			end
		end
	end
end

function EggUIHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	dataSync.OnReady(function()
		for _, egg in ipairs(eggs:GetChildren()) do
			ConfigureEggUI(egg)
		end
	end)

	dataSync.OnChanged("IsAutoHatching", function(new, _)
		autoHatching = new
	end)

	dataSync.OnChanged("HatchDebounce", function(new, _)
		if new == false then
			HatchComplete()
		end
	end)

	dataSync.OnChanged("UnlockedEggs", function(_, _)
		LoadEggModels()
	end)

	task.spawn(GetClosestEgg)

	uis.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.E then
				local egg = closestEgg2
				if egg ~= "" then
					if UnlockedEggs[egg] then
						network:FireServer("OpenEgg", egg, 1)
					else
						network:FireServer("UnlockEgg", egg)
					end
				end
			elseif input.KeyCode == Enum.KeyCode.R then
				local egg = closestEgg2
				if egg ~= "" then
					if UnlockedEggs[egg] then
						network:FireServer("OpenEgg", egg, dataSync.Get("EggHatches"))
					else
						network:FireServer("UnlockEgg", egg)
					end
				end
			elseif input.KeyCode == Enum.KeyCode.T then
				local egg = closestEgg2
				if egg ~= "" and not autoHatching then
					EggUIHandler.AutoHatch(egg)
				end
			end
		end
	end)
end

return EggUIHandler
