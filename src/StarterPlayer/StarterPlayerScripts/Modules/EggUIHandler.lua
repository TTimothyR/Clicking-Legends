local EggUIHandler = {}
local db = false

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")

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

local closestEgg2
local adornees = {}
local connections = {}
local maxDistance = 15
local autoHatching = false

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local eggUI = assets:WaitForChild("EggUI")
local eggHolder = playerGui:WaitForChild("EggUI")
local frames = playerGui:WaitForChild("Frames")
local infoFrame = frames:WaitForChild("Info")

-- Modules
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
				item.ImageLabel.ImageTransparency = 0.5
			else
				item.ImageLabel.ImageTransparency = 0
			end

			if discovered then
				item.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
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
						item.ImageLabel.ImageTransparency = 0.5
					else
						item.ImageLabel.ImageTransparency = 0
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
			if ui.Name == closestEgg2 and not uiLock.Value then
				if not next(connections[ui.Name]) then
					SetupTemplate(ui)
				end
				ui.Enabled = true
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
	clone.Parent = eggHolder

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
	table.insert(adornees, {
		part = egg:FindFirstChild("View"),
		distance = math.huge,
	})

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

	for petName, data in pairs(currentStats.Pets) do
		local petClone = petTemplate:Clone()
		local chance = globals.GetPetChance(luckPassOwned, luckPercentage, petName, egg.Name, false)
		local rarity = petStats[petName].Rarity

		petClone.Parent = holder
		petClone.Name = petName

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
			petClone.ImageLabel.ImageTransparency = 0.5
		else
			petClone.ImageLabel.ImageTransparency = 0
		end

		if not discovered then
			petClone.ImageLabel.ImageColor3 = Color3.fromRGB(0, 0, 0)
		end
		petClone.Visible = true
	end
	connections[egg.Name] = {}
end

function EggUIHandler.AutoHatch(eggName: string)
	network:FireServer("ToggleAutoHatch", eggName, true)
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

	task.spawn(GetClosestEgg)

	uis.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.E then
				local egg = closestEgg2
				if egg ~= "" then
					network:FireServer("OpenEgg", egg, 1)
				end
			elseif input.KeyCode == Enum.KeyCode.R then
				local egg = closestEgg2
				if egg ~= "" then
					network:FireServer("OpenEgg", egg, dataSync.Get("EggHatches"))
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
