local InventoryHandler = {}
local db = false

-- Types
type InventoryConnections = { [string]: TemplateConnections }

type TemplateConnections = {
	ClickConnection: RBXScriptConnection?,
	TooltipConnections: { [number]: RBXScriptConnection },
}

-- Services
local TweenService = game:GetService("TweenService")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local mps = game:GetService("MarketplaceService")

local Assets = rs:WaitForChild("Assets")

local Sounds = Assets:WaitForChild("Sounds")

local Framework = rs:WaitForChild("Framework")

local InterfaceUtility = require(Framework:WaitForChild("InterfaceUtility"))

local SoundHandler = require("./SoundHandler")
local Tooltip = require("./Tooltip")

-- Variables
repeat
	task.wait()
until players.LocalPlayer
local player: Player = players.LocalPlayer

local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local classes = rs:WaitForChild("Classes")

local menuHandlerLoaded = false
local shopHandlerLoaded = false

local selectedPetID = nil
local selectedItemName = nil
local selectedGiftID = nil

local petInfoConnections = {}
local itemInfoConnections = {}
local giftInfoConnections = {}

local itemConnections: InventoryConnections = {}
local petConnections: InventoryConnections = {}
local giftConnections: InventoryConnections = {}

local legendaryConnection: RBXScriptConnection = nil
local gradientsToAnimate = {}
local currentRotation: { value: number } = { value = 0 }
local animationLoaded = false :: boolean

local bulkButtonsConnected = false
local multiDeleteActive = false
local selectedPets = {}
local selectedPetAmount = 0

local increaseEquippedButtonCon: RBXScriptConnection
local increaseStorageButtonCon: RBXScriptConnection

local CreatePetClickConnection
local CreateItemClickConnection
local CreateGiftClickConnection

-- UI
local playerGui = player:WaitForChild("PlayerGui")
local frames = playerGui:WaitForChild("Frames")
local inventoryFrame = frames:WaitForChild("Inventory")
local warningFrame = frames:WaitForChild("Warning")

-- Anything pet or idk
local templates = inventoryFrame:WaitForChild("Templates")
local normalTemplate = templates:WaitForChild("Normal")
local secretTemplate = templates:WaitForChild("Secret")
local equippedSecretTemplate = templates:WaitForChild("EquippedSecret")
local main = inventoryFrame:WaitForChild("Main")
local statsFrame = main:WaitForChild("Stats")
local equippedStat = statsFrame:WaitForChild("Equipped")
local increaseEquippedButton = equippedStat:WaitForChild("Increase")
local storageStat = statsFrame:WaitForChild("Storage")
local increaseStorageButton = storageStat:WaitForChild("Increase")
local bulkButtons = main:WaitForChild("BulkButtons")
local equipBest = bulkButtons:WaitForChild("EquipBest")
local unequipAll = bulkButtons:WaitForChild("UnequipAll")
local deleteAll = bulkButtons:WaitForChild("DeleteAll")
local utilityButtons = main:WaitForChild("UtilityButtons")
local utilButtonsHolder = utilityButtons:WaitForChild("Holder")
local multiDeleteButton = utilButtonsHolder:WaitForChild("MultiDelete")
local inventory = main:WaitForChild("Inventory")
local holder = inventory:WaitForChild("ScrollingFrame")
local equippedTag = holder:WaitForChild("EquippedTag")
local petsTag = holder:WaitForChild("Pets")
local equippedHolder = holder:WaitForChild("Equipped")
local notEquippedHolder = holder:WaitForChild("NotEquipped")

-- Anything potion
local sideButtons = main:WaitForChild("SideButtons")
local sideButtonsHolder = sideButtons:WaitForChild("Holder")
local petsButton = sideButtonsHolder:WaitForChild("Pets")
local itemsButton = sideButtonsHolder:WaitForChild("Items")
local giftsButton = sideButtonsHolder:WaitForChild("Gifts")
local itemInventoryFrame = main:WaitForChild("ItemInventory")
local itemHolder = itemInventoryFrame:WaitForChild("ScrollingFrame")

local potionTemplate = templates:WaitForChild("PotionTemplate")
local categoryTag = templates:WaitForChild("CategoryTag")

local itemInfo = main:WaitForChild("ItemInfo")
local itemInfoHolder = itemInfo:WaitForChild("Holder")

local searchFrame = main:WaitForChild("Search")
local searchBox = searchFrame:WaitForChild("TextBox")

local petInfo = main:WaitForChild("PetInfo")
local multiDeleteInfo = petInfo:WaitForChild("MultiDeleteInfo")
local multiDeleteButtons = multiDeleteInfo:WaitForChild("Buttons")
local confirmMultiDelete = multiDeleteButtons:WaitForChild("Confirm")
local cancelMultiDelete = multiDeleteButtons:WaitForChild("Cancel")
local petInfoHolder = petInfo:WaitForChild("Holder")
local petInfoButtons = petInfoHolder:WaitForChild("Buttons")

-- Gamepass Inventory
local giftInfo = main:WaitForChild("GiftInfo")
local giftInfoHolder = giftInfo:WaitForChild("Holder")
local useGiftButton = giftInfoHolder:WaitForChild("Use") :: ImageButton
local giftInventory = main:WaitForChild("GiftInventory")
local giftList = giftInventory:WaitForChild("ScrollingFrame")
local giftTemplate = templates:WaitForChild("GiftTemplate")

-- Modules
local network = require(framework.Network)
local infMath = require(framework.InfiniteMath)
local petStats = require(library.PetStats)
local eggStats = require(library.EggStats)
local shopStats = require(library.ShopStats)
local items = require(library.Items)
local imageService = require(library.ImageService)
local globals = require(framework.Globals)
local tblUtil = require(framework.TableUtility)
local warning = require(classes.WarningPopup)
local dataSync = require(script.Parent.DataSyncClient)
local shopHandler = nil
local menuHandler = nil

-- Constants
local maxColSecret = 3
local maxColNormal = 6

-- Credits to: https://devforum.roblox.com/t/converting-a-color-to-a-hex-string/793018/2
local function toInteger(color)
	return math.floor(color.r * 255) * 256 ^ 2 + math.floor(color.g * 255) * 256 + math.floor(color.b * 255)
end

local function toHex(color)
	local int = toInteger(color)

	local current = int
	local final = ""

	local hexChar = {
		"A",
		"B",
		"C",
		"D",
		"E",
		"F",
	}

	repeat
		local remainder = current % 16
		local char = tostring(remainder)

		if remainder >= 10 then
			char = hexChar[1 + remainder - 10]
		end

		current = math.floor(current / 16)
		final = final .. char
	until current <= 0

	return "#" .. string.reverse(final)
end

local function GetBuffPercentage(buff, tier)
	for _, data in ipairs(items.Potions[tier].Buffs) do
		if data[1] == buff then
			return data[2]
		end
	end

	return 0
end

local function RemoveConnection(key: string, container: InventoryConnections)
	local connections = container[key]
	if container[key] then
		if connections.ClickConnection and connections.ClickConnection.Connected then
			connections.ClickConnection:Disconnect()
		end

		for _, connection: RBXScriptConnection in ipairs(connections.TooltipConnections) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end

		table.clear(connections.TooltipConnections)
	end
	container[key] = {
		ClickConnection = nil,
		TooltipConnections = {},
	}
end

local function SeparatePets(petsTbl, equipped)
	local normalTbl = {}
	local secretTbl = {}

	for _, petData in ipairs(petsTbl) do
		local clone = holder:FindFirstChild(petData.id, true)

		if searchBox.Text ~= "" and not clone then
			continue
		end
		if searchBox.Text ~= "" and not clone.Visible then
			continue
		end
		if petData.equipped == equipped then
			if petStats[petData.petName].Secret then
				table.insert(secretTbl, petData)
			else
				table.insert(normalTbl, petData)
			end
		end
	end

	return normalTbl, secretTbl
end

local function GetPetData(id: string)
	local pets = dataSync.Get("Pets")

	for _, data in ipairs(pets) do
		if data.id == id then
			return data
		end
	end
	return nil
end

local function GetPetAmount(pets, petName: string)
	local count = 0
	for _, petData in ipairs(pets) do
		if petData.petName == petName and not petData.shiny and not petData.locked then
			count += 1
		end
	end
	return count
end

local function SetEquipButtonColor(newStatus: boolean)
	local equipButton = petInfoButtons.Equip.Click
	local color = ""
	local text = ""
	if newStatus then
		color = "Red"
		text = "Unequip"
	else
		color = "Green"
		text = "Equip"
	end
	equipButton.Frame.UIGradient.Color = globals.ButtonPresets[color].Gradient
	equipButton.Frame.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	equipButton.Title.UIStroke.Color = globals.ButtonPresets[color].StrokeColor
	equipButton.Title.Text = text
end

local function LoadGiftInfo(giftID: string)
	local playerGifts = dataSync.Get("Gifts")
	local gamepassName = playerGifts[giftID]

	for _, con: RBXScriptConnection in ipairs(giftInfoConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end

	giftInfoHolder.GiftName.Text = gamepassName
	giftInfoHolder.Description.Text = string.format("Applies %s gamepass when used", gamepassName)
	giftInfoHolder.Icon.Image = imageService[gamepassName] or imageService["Placeholder"]

	local useConnection = useGiftButton.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			network:FireServer("UseGamepass", giftID, gamepassName)
		end
	end) :: RBXScriptConnection

	table.insert(giftInfoConnections, useConnection)
	giftInfoHolder.Visible = true
end

local function LoadItemInfo(itemName: string)
	local playerItems = dataSync.Get("Items")
	local isPotion = playerItems.Potions[itemName] ~= nil

	for _, con: RBXScriptConnection in ipairs(itemInfoConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end

	if isPotion then
		local nameSplit = string.split(itemName, "_")
		local buff, tier = nameSplit[1], nameSplit[2]
		local amount = playerItems.Potions[itemName]

		itemInfoHolder.ItemName.Text = buff .. " " .. tier
		itemInfoHolder.Amount.Text = "x" .. amount

		itemInfoHolder.Icon.Image = imageService[itemName] or imageService["Placeholder"]

		local buffPercentage = GetBuffPercentage(buff, tier)
		local itemDescription = itemInfoHolder.Info
		itemDescription.Description.Text =
			string.format(globals.PotionDescriptions[buff], toHex(globals.BuffColors[buff]), buffPercentage)
		itemDescription.Duration.Text = string.format("Lasts for %s minutes", items.Potions[tier].Duration / 60)

		local itemInfoButtons = itemInfoHolder.Buttons

		local useCon: RBXScriptConnection
		local useAllCon: RBXScriptConnection

		useCon = itemInfoButtons.Use.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				network:FireServer("UsePotion", itemName, false)
			end
		end)
		useAllCon = itemInfoButtons.UseAll.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				network:FireServer("UsePotion", itemName, true)
			end
		end)

		table.insert(itemInfoConnections, useCon)
		table.insert(itemInfoConnections, useAllCon)
	end

	itemInfoHolder.Visible = true
end

local function LoadPetInfo(id: string)
	local petData = GetPetData(id)
	if not petData then
		-- DEBUG TO BE REMOVED
		warn("Player does not own pet with ID:", id)
		return
	end
	for _, con: RBXScriptConnection in ipairs(petInfoConnections) do
		if con.Connected then
			con:Disconnect()
		end
	end

	local date = os.date("*t", petData.date)

	local xpNeeded = globals.XPForNextLevel(petData.level, petData.shiny)

	petInfoHolder.Icon.Image = imageService[petData.fullName] or imageService["Placeholder"]
	petInfoHolder.PetName.Text = petData.fullName
	petInfoHolder.FoundDate.Text = "Found on " .. date.day .. "/" .. date.month .. "/" .. (date.year - 2000)
	petInfoHolder.Level.Text = "Level " .. petData.level
	petInfoHolder.XP.Progress.Text = petData.xp .. " / " .. infMath.new(xpNeeded):GetSuffix(true) .. " XP"

	local clicks = globals.GetPetClicks(petData)
	local gems = globals.GetPetGems(petData)

	petInfoHolder.Stats.Clicks.Amount.Text = infMath.new(clicks):GetSuffix(true)
	petInfoHolder.Stats.Gems.Amount.Text = infMath.new(gems):GetSuffix(true)

	if petData.shiny then
		petInfoButtons.Shiny.Click.Title.Text = "Already Shiny"
	elseif petData.locked then
		petInfoButtons.Shiny.Click.Title.Text = "Locked"
	else
		petInfoButtons.Shiny.Click.Title.Text = "Make Shiny (" .. GetPetAmount(dataSync.Get("Pets"), petData.petName) .. "/8)"
	end

	SetEquipButtonColor(petData.equipped)

	local equipCon: RBXScriptConnection
	local deleteCon: RBXScriptConnection
	local shinyCon: RBXScriptConnection
	local lockCon: RBXScriptConnection
	local currentlyEquipped = petData.equipped
	equipCon = petInfoButtons.Equip.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if not currentlyEquipped then
				local success = network:InvokeServer("EquipPet", id)
				if not success then
					return
				end
				currentlyEquipped = true
				SetEquipButtonColor(currentlyEquipped)
				-- InventoryHandler.LoadInventory();
			else
				local success = network:InvokeServer("UnequipPet", id)
				if not success then
					return
				end
				currentlyEquipped = false
				SetEquipButtonColor(currentlyEquipped)
				-- InventoryHandler.LoadInventory();
			end
		end
	end)
	deleteCon = petInfoButtons.Delete.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local success = network:InvokeServer("DeletePet", id)
			if not success then
				return
			end
			selectedPetID = nil
			petInfoHolder.Visible = false

			-- InventoryHandler.LoadInventory();
			local obj = holder:FindFirstChild(id, true)
			if obj then
				obj:Destroy()
			end
			RemoveConnection(id, petConnections)
		end
	end)
	shinyCon = petInfoButtons.Shiny.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local success, usedIds = network:InvokeServer("MakeShiny", petData.petName)
			if not success then
				return
			end
			selectedPetID = nil
			petInfoHolder.Visible = false

			-- InventoryHandler.LoadInventory();
			for _, iteratorID in ipairs(usedIds) do
				RemoveConnection(iteratorID, petConnections)
				local obj = holder:FindFirstChild(iteratorID, true)
				if obj then
					obj:Destroy()
				end
			end
		end
	end)
	lockCon = petInfoHolder.Lock.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			local success, newState = network:InvokeServer("ToggleLock", petData.id)
			if not success then
				return
			end
			-- TODO: Make sure the lock button gets updated after the toggle
			petData.locked = newState
			-- LoadPetInfo(id);
			local petClone = holder:FindFirstChild(id, true)
			CreatePetClickConnection(petClone, petData)
			petClone.Frame.Locked.Visible = newState
		end
	end)
	table.insert(petInfoConnections, equipCon)
	table.insert(petInfoConnections, deleteCon)
	table.insert(petInfoConnections, shinyCon)
	table.insert(petInfoConnections, lockCon)

	selectedPetID = id
	petInfoHolder.Visible = true
end

CreateGiftClickConnection = function(clone, giftID: string, gamepassName: string)
	RemoveConnection(giftID, giftConnections)

	local tooltipConnections = Tooltip.SetupTooltip(
		clone.Click,
		"Gifts",
		{ gamepassName = gamepassName, reference = giftID }
	) :: { [number]: RBXScriptConnection }

	local clickCon = clone.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if selectedGiftID == giftID then
				selectedGiftID = nil
				giftInfoHolder.Visible = false
			else
				selectedGiftID = giftID
				LoadGiftInfo(giftID)
			end
		end
	end) :: RBXScriptConnection

	giftConnections[giftID].ClickConnection = clickCon
	giftConnections[giftID].TooltipConnections = tooltipConnections
end

CreateItemClickConnection = function(clone, itemName)
	RemoveConnection(itemName, itemConnections)

	local tooltipConnections =
		Tooltip.SetupTooltip(clone.Click, "Items", { itemName = itemName, reference = itemName, Potion = true })
	local clickCon: RBXScriptConnection = clone.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if selectedItemName == itemName then
				selectedItemName = nil
				itemInfoHolder.Visible = false
			else
				selectedItemName = itemName
				LoadItemInfo(itemName)
			end
		end
	end)

	itemConnections[itemName].ClickConnection = clickCon
	itemConnections[itemName].TooltipConnections = tooltipConnections
end

CreatePetClickConnection = function(clone, petData)
	RemoveConnection(petData.id, petConnections)

	local tooltipTbl = petData
	tooltipTbl.clicks = true
	tooltipTbl.gems = true
	tooltipTbl.ShowLevel = true
	tooltipTbl.reference = petData.id
	tooltipTbl.ShowExist = petStats[petData.petName].Secret
	local tooltipConnections = Tooltip.SetupTooltip(clone, "PetTooltip", petData)
	local clickCon = clone.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			if multiDeleteActive then
				if petData.locked then
					return
				end
				if selectedPets[petData.id] then
					selectedPets[petData.id] = nil
					selectedPetAmount -= 1
					clone.Frame.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
				else
					selectedPets[petData.id] = true
					selectedPetAmount += 1
					clone.Frame.ImageLabel.ImageColor3 = Color3.fromRGB(255, 0, 0)
				end
				multiDeleteInfo.Info.Text = selectedPetAmount .. " Pets selected"
			else
				if selectedPetID == petData.id then
					selectedPetID = nil
					petInfoHolder.Visible = false
				else
					selectedPetID = petData.id
					LoadPetInfo(petData.id)
				end
			end
		end
	end) :: RBXScriptConnection

	petConnections[petData.id].ClickConnection = clickCon
	petConnections[petData.id].TooltipConnections = tooltipConnections
end

local function CreateFullNameVariable(clone, petData)
	local fullNameValue = Instance.new("StringValue")
	fullNameValue.Parent = clone
	fullNameValue.Name = "FullName"
	fullNameValue.Value = petData.fullName
end

local function CreateEquippedPet(petData, template)
	local clone = template:Clone()
	clone.Parent = equippedHolder
	clone.Name = petData.id
	clone.Frame.Locked.Visible = petData.locked
	CreateFullNameVariable(clone, petData)
	clone.Frame.ImageLabel.Image = imageService[petData.fullName] or imageService["Placeholder"]
	clone.Frame.ImageLabel.Level.Text = petData.level
	if clone.Frame:FindFirstChild("PetName") then
		local egg = tblUtil.FindEgg(eggStats, petData.petName)
		local chance = eggStats[egg].Pets[petData.petName][1]

		if petData.shiny == true then
			chance /= 40
		end

		if chance == 0 then
			clone.Frame.Chance.Text = "Unknown"
		else
			local simplifiedChance = infMath.new((1 / chance) * 100)
			clone.Frame.Chance.Text = "1 in " .. simplifiedChance:GetSuffix(true)
		end
		clone.Frame.PetName.Text = petData.petName
	end
	local rarity = petStats[petData.petName].Rarity
	clone.Frame.BackgroundColor3 = globals.RarityColors[rarity]
	if rarity == "Legendary" then
		clone.Glow.Visible = true
		clone.Glow.Legendary.Enabled = true
		clone.Frame.Legendary.Enabled = true

		if animationLoaded then
			table.insert(gradientsToAnimate, clone.Glow.Legendary)
			table.insert(gradientsToAnimate, clone.Frame.Legendary)
		end
	end

	CreatePetClickConnection(clone, petData)
end

local function CreateNormalPet(petData)
	local clone = normalTemplate:Clone()
	clone.Parent = notEquippedHolder
	clone.Name = petData.id
	clone.Frame.Locked.Visible = petData.locked
	CreateFullNameVariable(clone, petData)

	local rarity = petStats[petData.petName].Rarity
	clone.Frame.BackgroundColor3 = globals.RarityColors[rarity]
	clone.Frame.ImageLabel.Image = imageService[petData.fullName] or imageService["Placeholder"]
	clone.Frame.ImageLabel.Level.Text = petData.level
	if rarity == "Legendary" then
		clone.Glow.Visible = true
		clone.Glow.Legendary.Enabled = true
		clone.Frame.Legendary.Enabled = true

		if animationLoaded then
			table.insert(gradientsToAnimate, clone.Glow.Legendary)
			table.insert(gradientsToAnimate, clone.Frame.Legendary)
		end
	end

	CreatePetClickConnection(clone, petData)
end

local function CreateSecretPet(petData)
	local clone = secretTemplate:Clone()
	clone.Name = petData.id
	clone.Parent = notEquippedHolder
	clone.Frame.PetName.Text = petData.petName
	clone.Frame.Locked.Visible = petData.locked

	CreateFullNameVariable(clone, petData)

	local egg = tblUtil.FindEgg(eggStats, petData.petName)
	local chance = eggStats[egg].Pets[petData.petName][1]

	if petData.shiny == true then
		chance /= 40
	end

	clone.Frame.ImageLabel.Image = imageService[petData.fullName] or imageService["Placeholder"]
	clone.Frame.ImageLabel.Level.Text = petData.level
	if chance == 0 then
		clone.Frame.Chance.Text = "Unknown"
	else
		local simplifiedChance = infMath.new((1 / chance) * 100)
		clone.Frame.Chance.Text = "1 in " .. simplifiedChance:GetSuffix(true)
	end

	clone.Glow.Visible = true
	clone.Glow.Legendary.Enabled = true
	clone.Frame.Legendary.Enabled = true

	if animationLoaded then
		table.insert(gradientsToAnimate, clone.Glow.Legendary)
		table.insert(gradientsToAnimate, clone.Frame.Legendary)
	end
	CreatePetClickConnection(clone, petData)
end

local function ReloadPetInfo()
	if not selectedPetID then
		return
	end
	if not inventoryFrame.Visible then
		return
	end
	if multiDeleteActive then
		return
	end
	LoadPetInfo(selectedPetID)
end

local function ReloadItemInfo()
	if not selectedItemName then
		return
	end
	if not inventoryFrame.Visible then
		return
	end
	LoadItemInfo(selectedItemName)
end

function InventoryHandler.LoadInventory()
	local function ClearMultiDelete()
		multiDeleteActive = false
		multiDeleteInfo.Visible = false
		if selectedPetID then
			petInfoHolder.Visible = true
		end
		for id, _ in pairs(selectedPets) do
			local obj = holder:FindFirstChild(id, true)

			if obj then
				obj.Frame.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
		table.clear(selectedPets)
		selectedPetAmount = 0
	end

	local ownedPasses = dataSync.Get("OwnedGamepasses")
	local ownsEquips = ownedPasses["Extra Equips"]
	local ownsStorageT1 = ownedPasses["+500 Pet Storage"]
	local ownsStorageT2 = ownedPasses["VIP"]

	if increaseEquippedButtonCon and increaseEquippedButtonCon.Connected then
		increaseEquippedButtonCon:Disconnect()
	end
	if increaseStorageButtonCon and increaseStorageButtonCon.Connected then
		increaseStorageButtonCon:Disconnect()
	end

	if not ownsEquips then
		increaseEquippedButtonCon = increaseEquippedButton.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				mps:PromptGamePassPurchase(player, shopStats.Gamepasses["Extra Equips"].GamepassID)
				shopHandler.ShowGreyFrame()
			end
		end)
	else
		increaseEquippedButton.Visible = false
	end
	if ownsStorageT1 and ownsStorageT2 then
		increaseStorageButton.Visible = false
	end
	if not ownsStorageT1 or not ownsStorageT2 then
		increaseStorageButtonCon = increaseStorageButton.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				if not ownsStorageT1 then
					mps:PromptGamePassPurchase(player, shopStats.Gamepasses["+500 Pet Storage"].GamepassID)
					shopHandler.ShowGreyFrame()
				elseif not ownsStorageT2 then
					mps:PromptGamePassPurchase(player, shopStats.Gamepasses["VIP"].GamepassID)
					shopHandler.ShowGreyFrame()
				end
			end
		end)
	end
	if not bulkButtonsConnected then
		searchBox.Focused:Connect(function()
			searchBox.Text = ""
			for _, descendant in ipairs(holder:GetDescendants()) do
				if descendant:IsA("ImageButton") then
					descendant.Visible = true
				end
			end
			InventoryHandler.LoadInventory()
		end)
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local txt = searchBox.Text
			if txt == "" then
				for _, descendant in ipairs(holder:GetDescendants()) do
					if descendant:IsA("ImageButton") then
						descendant.Visible = true
					end
				end
			else
				for _, descendant in ipairs(holder:GetDescendants()) do
					if descendant:IsA("ImageButton") then
						if not string.find(string.lower(descendant.FullName.Value), string.lower(txt)) then
							descendant.Visible = false
						end
					end
				end
			end
			InventoryHandler.LoadInventory()
		end)
		confirmMultiDelete.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				if not multiDeleteActive then
					return
				end
				if selectedPetAmount == 0 then
					ClearMultiDelete()
					return
				end

				local success, deletedIds = network:InvokeServer("DeleteSelection", selectedPets)
				if success then
					-- InventoryHandler.LoadInventory();
					for _, id in ipairs(deletedIds) do
						local obj = holder:FindFirstChild(id, true)

						if obj then
							obj:Destroy()
						end
						if selectedPetID == id then
							selectedPetID = nil
							petInfoHolder.Visible = false
						end
					end
					table.clear(selectedPets)
					ClearMultiDelete()
				end
			end
		end)
		cancelMultiDelete.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				ClearMultiDelete()
			end
		end)
		multiDeleteButton.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				if multiDeleteActive then
					ClearMultiDelete()
				else
					table.clear(selectedPets)
					selectedPetAmount = 0

					multiDeleteActive = true
					petInfoHolder.Visible = false
					multiDeleteInfo.Visible = true

					multiDeleteInfo.Info.Text = "0 Pets selected"
				end
			end
		end)
		equipBest.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				network:FireServer("EquipBest")
				-- if not success then return end;
				-- InventoryHandler.LoadInventory();
				-- if selectedPetID ~= nil then
				--     LoadPetInfo(selectedPetID);
				-- end
			end
		end)
		unequipAll.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				network:FireServer("UnequipAll")
				-- if not success then return end;
				-- InventoryHandler.LoadInventory();
				-- if selectedPetID ~= nil then
				--     LoadPetInfo(selectedPetID);
				-- end
			end
		end)
		deleteAll.Click.MouseButton1Click:Connect(function()
			if not db then
				db = true
				task.delay(0.15, function()
					db = false
				end)
				warning.new(nil, "Are you sure you want to delete all unlocked pets below the Legendary rarity?", function()
					menuHandler.handleOpenClose(inventoryFrame)
					local success, deletedIds = network:InvokeServer("DeleteAllUnlocked")
					if success then
						-- InventoryHandler.LoadInventory();
						for _, id in ipairs(deletedIds) do
							holder:FindFirstChild(id, true):Destroy()
							if selectedPetID == id then
								selectedPetID = nil
								petInfoHolder.Visible = false
							end
						end
					end
				end, function()
					menuHandler.handleOpenClose(inventoryFrame)
				end, warningFrame)
				menuHandler.handleOpenClose(warningFrame)
			end
		end)
		bulkButtonsConnected = true
	end

	local pets = dataSync.Get("Pets")
	local dupes = globals.GetPetDuplicates(pets)
	local normalTbl, secretTbl = SeparatePets(pets, false)
	local equippedNormalTbl, equippedSecretTbl = SeparatePets(pets, true)
	local totalEquipped = #equippedNormalTbl + #equippedSecretTbl
	local totalVisibleEquipped = dataSync.Get("CurrentEquips")
	table.sort(normalTbl, globals.SortPets)
	table.sort(equippedNormalTbl, globals.SortPets)

	if totalEquipped == 0 then
		equippedTag.Visible = false
		petsTag.Position = UDim2.new(0, 0, 0, 0)
	else
		equippedTag.Visible = true
		equippedTag.Position = UDim2.new(0, 0, 0, 0)
	end

	equipBest.Visible = (totalVisibleEquipped == 0)
	unequipAll.Visible = not (totalVisibleEquipped == 0)

	storageStat.TextLabel.Text = #pets .. "/" .. dataSync.Get("PetStorage")
	equippedStat.TextLabel.Text = totalVisibleEquipped .. "/" .. dataSync.Get("PetEquips")

	local handledPetIds = {}

	for _, petData in ipairs(equippedSecretTbl) do
		if notEquippedHolder:FindFirstChild(petData.id) then
			RemoveConnection(petData.id, petConnections)
			notEquippedHolder:FindFirstChild(petData.id):Destroy()
		end
		if not equippedHolder:FindFirstChild(petData.id) then
			CreateEquippedPet(petData, equippedSecretTemplate)
		else
			equippedHolder:FindFirstChild(petData.id).Frame.ImageLabel.Level.Text = petData.level
		end
		handledPetIds[petData.id] = true
	end
	for _, petData in ipairs(equippedNormalTbl) do
		if notEquippedHolder:FindFirstChild(petData.id) then
			RemoveConnection(petData.id, petConnections)
			notEquippedHolder:FindFirstChild(petData.id):Destroy()
		end
		if not equippedHolder:FindFirstChild(petData.id) then
			CreateEquippedPet(petData, normalTemplate)
		else
			equippedHolder:FindFirstChild(petData.id).Frame.ImageLabel.Level.Text = petData.level
		end
		handledPetIds[petData.id] = true
	end

	for _, petData in ipairs(secretTbl) do
		if equippedHolder:FindFirstChild(petData.id) then
			RemoveConnection(petData.id, petConnections)
			equippedHolder:FindFirstChild(petData.id):Destroy()
		end
		if not notEquippedHolder:FindFirstChild(petData.id) then
			CreateSecretPet(petData)
		else
			notEquippedHolder:FindFirstChild(petData.id).Frame.ImageLabel.Level.Text = petData.level
		end
		handledPetIds[petData.id] = true
	end
	for _, petData in ipairs(normalTbl) do
		if equippedHolder:FindFirstChild(petData.id) then
			RemoveConnection(petData.id, petConnections)
			equippedHolder:FindFirstChild(petData.id):Destroy()
		end
		if not notEquippedHolder:FindFirstChild(petData.id) then
			CreateNormalPet(petData)
		else
			notEquippedHolder:FindFirstChild(petData.id).Frame.ImageLabel.Level.Text = petData.level
		end
		handledPetIds[petData.id] = true
	end

	for _, descendant in ipairs(holder:GetDescendants()) do
		if descendant:IsA("ImageButton") then
			if not handledPetIds[descendant.Name] then
				RemoveConnection(descendant.Name, petConnections)
				descendant:Destroy()
			end
		end
	end

	local function SetImageColor(clone, petData)
		local imageHolder = clone:FindFirstChild("Frame") :: Frame?
		local imageLabel = imageHolder:FindFirstChild("ImageLabel") :: ImageLabel?
		if dupes[petData.id] then
			imageLabel.ImageColor3 = Color3.fromRGB(255, 0, 0)
		else
			imageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	local lastEquippedRow = -1

	for i, petData in ipairs(equippedSecretTbl) do
		local row = math.floor((i - 1) / maxColNormal)
		local col = math.floor((i - 1) % maxColNormal)

		local clone: ImageButton = equippedHolder:FindFirstChild(petData.id)
		if not clone then
			continue
		end
		SetImageColor(clone, petData)
		clone.Position = UDim2.new(
			equippedSecretTemplate.Size.X.Scale * col + equippedSecretTemplate.Size.X.Scale / 2,
			0,
			equippedSecretTemplate.Size.Y.Scale * row + equippedSecretTemplate.Size.Y.Scale / 2 + equippedTag.Size.Y.Scale,
			0
		)

		lastEquippedRow = row
		clone.Visible = true
	end
	for i, petData in ipairs(equippedNormalTbl) do
		local row = math.floor((i + #equippedSecretTbl - 1) / maxColNormal)
		local col = math.floor((i + #equippedSecretTbl - 1) % maxColNormal)

		local clone: ImageButton = equippedHolder:FindFirstChild(petData.id)
		if not clone then
			continue
		end
		SetImageColor(clone, petData)
		clone.Position = UDim2.new(
			normalTemplate.Size.X.Scale * col + normalTemplate.Size.X.Scale / 2,
			0,
			normalTemplate.Size.Y.Scale * row + normalTemplate.Size.Y.Scale / 2 + equippedTag.Size.Y.Scale,
			0
		)

		lastEquippedRow = row
		clone.Visible = true
	end

	lastEquippedRow += 1

	local tagCorrection = 0
	if equippedTag.Visible then
		tagCorrection += equippedTag.Size.Y.Scale
	end

	petsTag.Position = UDim2.fromScale(0, normalTemplate.Size.Y.Scale * lastEquippedRow + tagCorrection)

	tagCorrection += petsTag.Size.Y.Scale

	local lastRow = 0
	local lastColumn = 0

	for i, petData in ipairs(secretTbl) do
		local row = math.floor((i - 1) / maxColSecret)
		lastRow = (row + 1) * 2
		local column = math.floor((i - 1) % maxColSecret)
		lastColumn = ((column + 1) % maxColSecret) * 2

		local clone: ImageButton = notEquippedHolder:FindFirstChild(petData.id)
		if not clone then
			continue
		end
		SetImageColor(clone, petData)

		clone.Position = UDim2.new(
			secretTemplate.Size.X.Scale * column + secretTemplate.Size.X.Scale / 2,
			0,
			secretTemplate.Size.Y.Scale * row
				+ secretTemplate.Size.Y.Scale / 2
				+ normalTemplate.Size.Y.Scale * lastEquippedRow
				+ tagCorrection,
			0
		)

		clone.Visible = true
	end

	local savedColumn = lastColumn
	local rowsFilled = 0
	local finalIndex = 0
	local secretRows = math.ceil(#secretTbl / maxColSecret)
	local yPaddingCorrection = 0.043
	local equipCorrection = (totalEquipped == 0) and 0 or yPaddingCorrection * 3
	local finalCorrection = lastEquippedRow == 0 and normalTemplate.Size.Y.Scale / 2 or 0

	for i, petData in ipairs(normalTbl) do
		local clone: ImageButton = notEquippedHolder:FindFirstChild(petData.id)
		if not clone then
			continue
		end
		SetImageColor(clone, petData)

		if lastColumn > 0 and rowsFilled < 2 then
			local targetColumn = lastColumn + 1
			local row = math.floor((i - 1) / (maxColNormal - savedColumn))

			lastColumn += 1
			if lastColumn == 6 then
				rowsFilled += 1
				lastColumn = savedColumn
				lastRow += 1
			end

			local xPos = normalTemplate.Size.X.Scale * (targetColumn - 1) + normalTemplate.Size.X.Scale / 2
			local yPos = secretTemplate.Size.Y.Scale * (secretRows - 1)
				+ (normalTemplate.Size.Y.Scale - yPaddingCorrection) * row
				+ (normalTemplate.Size.Y.Scale * lastEquippedRow)
				+ equipCorrection
				+ finalCorrection
				+ tagCorrection
			clone.Position = UDim2.fromScale(xPos, yPos)
			finalIndex = i
		else
			local targetRow = secretRows * 2 + math.floor((i - finalIndex - 1) / maxColNormal)
			local targetColumn = math.floor((i - finalIndex - 1) % maxColNormal)

			local xPos = normalTemplate.Size.X.Scale * targetColumn + normalTemplate.Size.X.Scale / 2
			local yPos = secretTemplate.Size.Y.Scale * secretRows
				+ (normalTemplate.Size.Y.Scale - yPaddingCorrection) * (targetRow - secretRows * 2)
				+ (normalTemplate.Size.Y.Scale * lastEquippedRow)
				+ equipCorrection
				+ finalCorrection
				+ tagCorrection
			clone.Position = UDim2.fromScale(xPos, yPos)
		end

		clone.Visible = true
	end
end

function InventoryHandler.LoadGifts()
	local playerGifts = dataSync.Get("Gifts")
	for _, child in ipairs(giftList:GetChildren()) do
		if not playerGifts[child.Name] and child:IsA("Frame") then
			RemoveConnection(child.Name, giftConnections)
			child:Destroy()
			giftInfoHolder.Visible = false
		end
	end

	for id, gamepassName in pairs(playerGifts) do
		if giftList:FindFirstChild(id) then
			continue
		end

		local clone = giftTemplate:Clone() :: Frame
		clone.Name = id
		clone.Parent = giftList

		local newFrame = clone.Click

		newFrame.Glow.Visible = true
		newFrame.Glow.Legendary.Enabled = true
		newFrame.Frame.Legendary.Enabled = true
		newFrame.Frame.Icon.Image = imageService[gamepassName] or imageService["Placeholder"]

		if animationLoaded then
			table.insert(gradientsToAnimate, newFrame.Glow.Legendary)
			table.insert(gradientsToAnimate, newFrame.Frame.Legendary)
		end

		CreateGiftClickConnection(clone, id, gamepassName)

		clone.Visible = true
	end
end

function InventoryHandler.LoadItems()
	local playerItems = dataSync.Get("Items")
	local potions = playerItems.Potions

	local sortedPotions = {}

	for potionName, amount in pairs(potions) do
		local nameSplit = string.split(potionName, "_")
		local buff, tier = nameSplit[1], nameSplit[2]
		local rarity = items.Potions[tier].Rarity

		table.insert(sortedPotions, { potionName = potionName, buff = buff, tier = tier, rarity = rarity, amount = amount })
	end

	table.sort(sortedPotions, function(a, b)
		local orderA = globals.RarityOrder[a.rarity]
		local orderB = globals.RarityOrder[b.rarity]

		if orderA ~= orderB then
			return orderA > orderB
		end

		return a.buff < b.buff
	end)

	local currentOrder = 0

	if not itemHolder:FindFirstChild("PotionTag") then
		if next(potions) ~= nil then
			local tagClone = categoryTag:Clone()
			tagClone.Parent = itemHolder
			tagClone.Name = "PotionTag"
			tagClone.Text = "~ Potions ~"
			tagClone.LayoutOrder = currentOrder
			tagClone.Visible = true
		end
	else
		if next(potions) == nil then
			itemHolder:FindFirstChild("PotionTag"):Destroy()
		end
	end

	for _, child in ipairs(itemHolder:GetChildren()) do
		if child:IsA("Frame") then
			if not potions[child.Name] then
				RemoveConnection(child.Name, itemConnections)
				child:Destroy()
			end
		end
	end

	for _, data in ipairs(sortedPotions) do
		if itemHolder:FindFirstChild(data.potionName) then
			local clone = itemHolder:FindFirstChild(data.potionName)
			clone.Click.Frame.Amount.Text = "x" .. data.amount
		else
			currentOrder += 1
			local clone = potionTemplate:Clone()
			local potionTier = data.tier
			--local potionImage = potionTemplates:WaitForChild(data.tier):Clone()
			local potionImage = (imageService[data.potionName] or "")
			--potionImage.Liquid.ImageColor3 = color

			--potionImage.Parent = clone.Frame
			--potionImage.Visible = true

			local rarity = data.rarity
			clone.Click.Frame.BackgroundColor3 = globals.RarityColors[rarity]
			clone.Click.Frame.Frame.Icon.Image = potionImage

			if potionTier == "V" then
				clone.Click.Frame.Frame.Icon.Size = UDim2.fromScale(0.95, 0.95)
				clone.Click.Frame.Frame.Icon.Position = UDim2.fromScale(0.5, 0.5)
			end

			if rarity == "Legendary" then
				clone.Click.Glow.Visible = true
				clone.Click.Glow.Legendary.Enabled = true
				clone.Click.Frame.Legendary.Enabled = true

				if animationLoaded then
					table.insert(gradientsToAnimate, clone.Click.Glow.Legendary)
					table.insert(gradientsToAnimate, clone.Click.Frame.Legendary)
				end
			end

			clone.Name = data.potionName
			clone.Click.Frame.PotionName.Text = data.buff .. " " .. data.tier
			clone.Click.Frame.Amount.Text = "x" .. data.amount

			clone.LayoutOrder = currentOrder
			clone.Parent = itemHolder

			CreateItemClickConnection(clone, data.potionName)

			clone.Visible = true
		end
	end
end

function InventoryHandler.ParseMenuHandler(handler)
	if menuHandlerLoaded then
		return
	end
	menuHandlerLoaded = true
	menuHandler = handler
end

function InventoryHandler.ParseShopHandler(handler)
	if shopHandlerLoaded then
		return
	end
	shopHandlerLoaded = true
	shopHandler = handler
end

function InventoryHandler.NewItem(data)
	local hideItemPopups = dataSync.Get("Settings").HideItemPopups

	if hideItemPopups then
		return
	end

	local clone = potionTemplate:Clone()
	local potionTier = data.tier
	--local potionImage = potionTemplates:WaitForChild(data.tier):Clone()
	local potionImage = (imageService[data.potionName] or "")
	--potionImage.Liquid.ImageColor3 = color

	--potionImage.Parent = clone.Frame
	--potionImage.Visible = true

	local rarity = data.rarity
	clone.Frame.BackgroundColor3 = globals.RarityColors[rarity]
	clone.Frame.Frame.Icon.Image = potionImage

	if potionTier == "V" then
		clone.Frame.Frame.Icon.Size = UDim2.fromScale(0.95, 0.95)
		clone.Frame.Frame.Icon.Position = UDim2.fromScale(0.5, 0.5)
	end

	if rarity == "Legendary" then
		clone.Glow.Visible = true
		clone.Frame.Legendary.Enabled = true
	end

	clone.Name = data.potionName
	clone.Frame.PotionName.Text = data.buff .. " " .. data.tier
	clone.Frame.Amount.Text = "x" .. data.amount

	clone.Parent = frames.NewItems

	clone.Visible = true

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = clone

	SoundHandler.PlaySound(Sounds.NewItem)

	task.wait(0.1)

	local Tween =
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Tween:Play()

	local Conn
	Conn = Tween.Completed:Connect(function()
		Conn:Disconnect()
		Conn = nil

		for _ = 1, 3 do
			InterfaceUtility.PlayWhiteOutAnim(clone.Template, clone.Anims, 0.5, 1.3)
			task.wait(0.55)
		end

		task.delay(0.5, function()
			Tween =
				TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0 })
			Tween:Play()

			Conn = Tween.Completed:Connect(function()
				Tween:Destroy()
				Conn:Disconnect()
				Conn = nil
				clone:Destroy()
			end)
		end)
	end) :: RBXScriptConnection
end

function InventoryHandler.StartLegendaryAnimations()
	globals.GetAnimatedGradients({
		notEquippedHolder,
		equippedHolder,
		giftList,
		itemHolder,
	}, gradientsToAnimate)

	legendaryConnection =
		InterfaceUtility.CreateGradientAnimation(gradientsToAnimate, currentRotation) :: RBXScriptConnection

	animationLoaded = true
end

function InventoryHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	inventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if inventoryFrame.Visible == false then
			if legendaryConnection.Connected then
				legendaryConnection:Disconnect()
				table.clear(gradientsToAnimate)
				animationLoaded = false
			end
		end
	end)

	dataSync.OnChanged("Pets", function()
		if not inventoryFrame.Visible then
			return
		end
		InventoryHandler.LoadInventory()
		ReloadPetInfo()
	end)

	dataSync.OnChanged("PetEquips", function()
		if not inventoryFrame.Visible then
			return
		end
		InventoryHandler.LoadInventory()
	end)
	dataSync.OnChanged("CurrentEquips", function()
		if not inventoryFrame.Visible then
			return
		end
		InventoryHandler.LoadInventory()
	end)

	dataSync.OnChanged("PetStorage", function()
		if not inventoryFrame.Visible then
			return
		end
		InventoryHandler.LoadInventory()
	end)

	dataSync.OnChanged("Gifts", function()
		if not inventoryFrame.Visible then
			return
		end
		InventoryHandler.LoadGifts()
	end)

	dataSync.OnChanged("Items", function()
		if not inventoryFrame.Visible then
			return
		end
		InventoryHandler.LoadItems()
		ReloadItemInfo()
	end)

	petsButton.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			itemInventoryFrame.Visible = false
			itemInfo.Visible = false

			giftInventory.Visible = false
			giftInfo.Visible = false

			inventory.Visible = true
			petInfo.Visible = true
			bulkButtons.Visible = true
			utilityButtons.Visible = true
			searchFrame.Visible = true
		end
	end)
	itemsButton.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			itemInventoryFrame.Visible = true
			itemInfo.Visible = true

			giftInventory.Visible = false
			giftInfo.Visible = false

			inventory.Visible = false
			petInfo.Visible = false
			bulkButtons.Visible = false
			utilityButtons.Visible = false
			searchFrame.Visible = false
		end
	end)

	giftsButton.Click.MouseButton1Click:Connect(function()
		if not db then
			db = true
			task.delay(0.15, function()
				db = false
			end)
			itemInventoryFrame.Visible = false
			itemInfo.Visible = false

			giftInventory.Visible = true
			giftInfo.Visible = true

			inventory.Visible = false
			petInfo.Visible = false
			bulkButtons.Visible = false
			utilityButtons.Visible = false
			searchFrame.Visible = false
		end
	end)
end

return InventoryHandler
