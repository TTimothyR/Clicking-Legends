local RewardHandler = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local sss = game:GetService("ServerScriptService")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local dataModules = sss:WaitForChild("DataModules")
local assets = rs:WaitForChild("Assets")
local petModels = assets:WaitForChild("PetModels")
local framework = rs:WaitForChild("Framework")

-- Modules
local Network = require(ReplicatedStorage.Framework.Network)
local DataSyncServer = require(ServerScriptService.DataModules.DataSyncServer).Private
local playerData = require(dataModules.PlayerData)
local generateID = require(framework.GenerateID)
local infMath = require(framework.InfiniteMath)

function RewardHandler.ClaimPet(player: Player, fullName: string, shiny: boolean, enchant: string)
	local profile = playerData.GetData(player)

	local petName: string = shiny and string.gsub(fullName, "Shiny ", "") or fullName
	if not petModels:FindFirstChild(fullName) then
		return false, "SERVER - Invalid pet name, unable to claim prize."
	end

	local pets = profile.Pets
	local id = generateID.NewID()

	if not profile.PetIndex[fullName] then
		profile.PetIndex[fullName] = true
	end

	if not enchant then
		enchant = ""
	end

	table.insert(pets, {
		petName = petName,
		fullName = fullName,
		shiny = shiny,
		id = id,
		level = 1,
		xp = 0,
		date = os.time(),
		locked = false,
		equipped = false,
		enchant = enchant,
	})

	Network:FireClient(player, "NewItem", {
		itemName = fullName,
		amount = 1,
		type = "Pets",
	})

	return true
end

function RewardHandler.ClaimPotion(player: Player, potionName: string, amount: number)
	local profile = playerData.GetData(player)
	local playerItems = profile.Items
	local potions = playerItems.Potions

	if not potions[potionName] then
		potions[potionName] = amount
	else
		potions[potionName] += amount
	end

	Network:FireClient(player, "NewItem", {
		itemName = potionName,
		amount = amount,
		type = "Potions",
	})

	DataSyncServer.SyncPlayer(player, profile)
end

function RewardHandler.ClaimCurrency(player: Player, currencyStr: string, amount: number)
	local profile = playerData.GetData(player)

	if not profile[currencyStr] then
		return false, "SERVER - Invalid currency string, unable to claim prize."
	end

	local currentValue = infMath.new(profile[currencyStr])
	local increment = infMath.new(amount)
	profile[currencyStr] = infMath.new(currentValue + increment)

	local leaderstats = player:FindFirstChild("leaderstats") :: Folder
	for _, instance in ipairs(leaderstats:GetDescendants()) do
		if instance.Name == currencyStr then
			instance.Value = profile[currencyStr]:GetSuffix(true)
		end
	end

	-- Network:FireClient(player, "NewItem", {
	-- 	potionName = currencyStr,
	-- 	tier = nil,
	-- 	buff = nil,
	-- 	amount = amount,
	-- 	rarity = "Common",
	-- })

	DataSyncServer.SyncPlayer(player, profile)

	return true
end

function RewardHandler.ClaimPerk(player: Player, perkStr: string, amount: number)
	local profile = playerData.GetData(player)

	if not profile[perkStr] then
		return false, "SERVER - Perk not found, unable to claim prize."
	end

	profile[perkStr] += amount

	DataSyncServer.SyncPlayer(player, profile)

	return true
end

return RewardHandler
