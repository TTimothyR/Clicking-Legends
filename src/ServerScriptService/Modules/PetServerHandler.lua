local PetHandler = {}

-- Services
local HttpService = game:GetService("HttpService")
local players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local dataModules = sss:WaitForChild("DataModules")
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local BotHandler = require(script.Parent.BotHandler).Private
local playerData = require(dataModules.PlayerData)
local tblUtil = require(framework.TableUtility)
local network = require(framework.Network)
local globals = require(framework.Globals)
local generateID = require(framework.GenerateID)
local petStats = require(library.PetStats)
local dataSync = require(dataModules.DataSyncServer).Private

local function GetPetAmount(profile, petName: string)
	local count = 0
	for _, petData in ipairs(profile.Pets) do
		if petData.petName == petName and not petData.shiny and not petData.locked then
			count += 1
		end
	end
	return count
end

function PetHandler.LevelUp(player: Player, id: string)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end

	local pets = profile.Pets
	local index, petData = tblUtil.FindIndexWithId(pets, id)
	if not index then
		return
	end

	local xpNeeded = globals.XPForNextLevel(petData.level, petData.shiny)
	if petData.xp >= xpNeeded then
		petData.xp = 0
		petData.level += 1
	else
		return
	end

	dataSync.SyncPlayer(player, profile)
end

function PetHandler.EquipPet(player: Player, id: string)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end
	if profile.CurrentEquips >= profile.PetEquips then
		return false
	end

	local pets = profile.Pets
	local index, petData = tblUtil.FindIndexWithId(pets, id)
	if not index then
		return false
	end

	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePet", player, petData, true)
	end

	petData.equipped = true
	profile.CurrentEquips += 1

	dataSync.SyncPlayer(player, profile)
	return true
end

function PetHandler.EquipBest(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end

	local pets = profile.Pets

	local statTable = {}

	for _, petData in ipairs(pets) do
		if petData.equipped then
			petData.equipped = false
			profile.CurrentEquips -= 1
		end

		table.insert(statTable, { petData = petData, Clicks = globals.GetMaxLevelClicks(petData) })
	end

	table.sort(statTable, function(a, b)
		return a.Clicks > b.Clicks
	end)
	for i = 1, profile.PetEquips do
		if not statTable[i] then
			continue
		end
		local petData = statTable[i].petData
		petData.equipped = true
		profile.CurrentEquips += 1
	end
	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePets", player, table.clone(profile.Pets))
	end

	dataSync.SyncPlayer(player, profile)
end

function PetHandler.UnequipAll(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end

	local pets = profile.Pets
	for _, petData in ipairs(pets) do
		if petData.equipped then
			petData.equipped = false
			profile.CurrentEquips -= 1
		end
	end

	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePets", player, table.clone(profile.Pets))
	end

	dataSync.SyncPlayer(player, profile)
end

function PetHandler.UnequipPet(player: Player, id: string)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end

	local pets = profile.Pets
	local index, petData = tblUtil.FindIndexWithId(pets, id)
	if not index then
		return false
	end

	if not petData.equipped then
		return false
	end

	petData.equipped = false
	profile.CurrentEquips -= 1
	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePet", player, petData, false)
	end

	dataSync.SyncPlayer(player, profile)
	return true
end

function PetHandler.DeletePet(player: Player, id: string)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end

	if profile.IsInTrade then
		return false
	end

	local pets = profile.Pets
	local index, petData = tblUtil.FindIndexWithId(pets, id)
	if not index then
		return false
	end

	if petData.locked then
		return false
	end

	if petData.equipped then
		petData.equipped = false
		profile.CurrentEquips -= 1
		for _, plr: Player in ipairs(players:GetPlayers()) do
			network:FireClient(plr, "UpdatePet", player, petData, false)
		end
	end
	table.remove(pets, index)

	if petStats[petData.petName].Secret == true or petStats[petData.petName].Exclusive == true then
		local changes = {
			{ petName = petData.petName, isShiny = petData.shiny, delta = -1 },
		}

		task.spawn(function()
			BotHandler.Delete(HttpService:JSONEncode(changes))
		end)
	end

	local dupes = globals.GetPetDuplicates(profile.Pets)
	profile.TradeBanned = next(dupes) ~= nil

	dataSync.SyncPlayer(player, profile)

	return true
end

function PetHandler.DeleteAllUnlocked(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end

	if profile.IsInTrade then
		return false
	end

	local idsToRemove = {}
	local pets = profile.Pets

	for _, petData in ipairs(pets) do
		if petData.locked then
			continue
		end
		if petStats[petData.petName].Rarity == "Legendary" then
			continue
		end
		if petStats[petData.petName].Rarity == "Secret" then
			continue
		end
		if petData.equipped then
			petData.equipped = false
			profile.CurrentEquips -= 1
		end
		table.insert(idsToRemove, petData.id)
	end
	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePets", player, table.clone(pets))
	end

	local changes = {}

	for _, id in ipairs(idsToRemove) do
		local index, petData = tblUtil.FindIndexWithId(pets, id)
		table.remove(pets, index)

		if petStats[petData.petName].Secret == true or petStats[petData.petName].Exclusive == true then
			local found = false
			for _, entry in ipairs(changes) do
				if entry.petName == petData.petName and entry.isShiny == petData.shiny then
					entry.delta -= 1
					found = true
					break
				end
			end
			if found then
				break
			else
				table.insert(changes, {
					petName = petData.petName,
					isShiny = petData.shiny,
					delta = -1,
				})
			end
		end
	end

	if #changes > 0 then
		task.spawn(function()
			BotHandler.Delete(HttpService:JSONEncode(changes))
		end)
	end

	local dupes = globals.GetPetDuplicates(profile.Pets)
	profile.TradeBanned = next(dupes) ~= nil

	dataSync.SyncPlayer(player, profile)

	return true, idsToRemove
end

function PetHandler.DeleteSelection(player: Player, selection)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end

	if profile.IsInTrade then
		return false
	end

	local idsToRemove = {}
	local pets = profile.Pets

	for id, _ in pairs(selection) do
		local index, petData = tblUtil.FindIndexWithId(pets, id)
		if not index then
			continue
		end
		if petData.locked then
			continue
		end

		if petData.equipped then
			petData.equipped = false
			profile.CurrentEquips -= 1
		end
		table.insert(idsToRemove, id)
	end

	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePets", player, table.clone(profile.Pets))
	end

	local changes = {}

	for _, id in ipairs(idsToRemove) do
		local index, petData = tblUtil.FindIndexWithId(pets, id)
		table.remove(pets, index)

		if petStats[petData.petName].Secret == true or petStats[petData.petName].Exclusive == true then
			local found = false
			for _, entry in ipairs(changes) do
				if entry.petName == petData.petName and entry.isShiny == petData.shiny then
					entry.delta -= 1
					found = true
					break
				end
			end
			if found then
				break
			else
				table.insert(changes, {
					petName = petData.petName,
					isShiny = petData.shiny,
					delta = -1,
				})
			end
		end
	end

	if #changes > 0 then
		task.spawn(function()
			BotHandler.Delete(HttpService:JSONEncode(changes))
		end)
	end

	local dupes = globals.GetPetDuplicates(profile.Pets)
	profile.TradeBanned = next(dupes) ~= nil

	dataSync.SyncPlayer(player, profile)

	return true, idsToRemove
end

function PetHandler.CraftAll(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return false, nil
	end
	if profile.TradeBanned then
		return false, nil
	end
	if profile.IsInTrade then
		return false, nil
	end

	local normalPetCounts = {}

	for _, petData in ipairs(profile.Pets) do
		if petData.shiny or petData.locked then
			continue
		end
		if not normalPetCounts[petData.petName] then
			normalPetCounts[petData.petName] = { Count = 1, PetData = { petData } }
		else
			normalPetCounts[petData.petName].Count += 1
			table.insert(normalPetCounts[petData.petName].PetData, petData)
		end
	end

	local targetShinyPetCounts = {}

	for petName, data in pairs(normalPetCounts) do
		if data.Count < 8 then
			continue
		end

		local shinyCount = math.floor(data.Count / 8)
		targetShinyPetCounts[petName] = { Count = shinyCount, PetData = data.PetData }
	end

	for _, data in pairs(targetShinyPetCounts) do
		local eligiblePets = #data.PetData
		local extraAmount = eligiblePets - data.Count * 8

		for i = extraAmount, 1, -1 do
			table.remove(data.PetData, i)
		end
	end

	local idsToRemove = {}

	for _, data in pairs(targetShinyPetCounts) do
		for _, petData in ipairs(data.PetData) do
			table.insert(idsToRemove, petData.id)
			if petData.equipped then
				petData.equipped = false
				profile.CurrentEquips -= 1
			end
		end
	end
	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePets", player, table.clone(profile.Pets))
	end

	local removeSet = {}

	for _, id in ipairs(idsToRemove) do
		removeSet[id] = true
	end

	local newPets = {}
	for _, petData in ipairs(profile.Pets) do
		if not removeSet[petData.id] then
			table.insert(newPets, petData)
		end
	end
	profile.Pets = newPets

	local changes = {}

	for petName, data in pairs(targetShinyPetCounts) do
		if not profile.PetIndex["Shiny " .. petName] then
			profile.PetIndex["Shiny " .. petName] = true
		end

		table.insert(profile.Pets, {
			petName = petName,
			fullName = "Shiny " .. petName,
			shiny = true,
			id = generateID.NewID(),
			level = 1,
			xp = 0,
			date = os.time(),
			locked = false,
			equipped = false,
			enchant = data.PetData[1].enchant,
		})

		if petStats[petName].Secret == true or petStats[petName].Exclusive == true then
			table.insert(changes, { petName = petName, isShiny = false, delta = -data.Count * 8 })
			table.insert(changes, { petName = petName, isShiny = true, delta = data.Count })
		end
	end

	if #changes > 0 then
		task.spawn(function()
			BotHandler.Craft(HttpService:JSONEncode(changes))
		end)
	end

	local dupes = globals.GetPetDuplicates(profile.Pets)
	profile.TradeBanned = next(dupes) ~= nil

	dataSync.SyncPlayer(player, profile)

	return true, idsToRemove
end

function PetHandler.MakeShiny(player: Player, petName: string)
	local profile = playerData.GetData(player)
	if not profile then
		return false, nil
	end
	if profile.TradeBanned then
		return false, nil
	end

	if profile.IsInTrade then
		return false, nil
	end
	if GetPetAmount(profile, petName) < 8 then
		return false, nil
	end

	local idsToRemove = {}
	local pets = profile.Pets

	local enchant = ""

	local count = 0
	for _, petData in ipairs(pets) do
		if count == 8 then
			break
		end
		if petData.petName == petName and not petData.shiny and not petData.locked then
			enchant = petData.enchant
			table.insert(idsToRemove, petData.id)
			count += 1
			if petData.equipped then
				petData.equipped = false
				profile.CurrentEquips -= 1
			end
		end
	end
	for _, plr: Player in ipairs(players:GetPlayers()) do
		network:FireClient(plr, "UpdatePets", player, table.clone(pets))
	end

	for _, id in ipairs(idsToRemove) do
		local index, _ = tblUtil.FindIndexWithId(pets, id)
		table.remove(pets, index)
	end

	if not profile.PetIndex["Shiny " .. petName] then
		profile.PetIndex["Shiny " .. petName] = true
	end

	table.insert(pets, {
		petName = petName,
		fullName = "Shiny " .. petName,
		shiny = true,
		id = generateID.NewID(),
		level = 1,
		xp = 0,
		date = os.time(),
		locked = false,
		equipped = false,
		enchant = enchant,
	})

	if petStats[petName].Secret == true or petStats[petName].Exclusive == true then
		local changes = {
			{ petName = petName, isShiny = false, delta = -8 },
			{ petName = petName, isShiny = true, delta = 1 },
		}
		task.spawn(function()
			BotHandler.Craft(HttpService:JSONEncode(changes))
		end)
	end

	local dupes = globals.GetPetDuplicates(profile.Pets)
	profile.TradeBanned = next(dupes) ~= nil

	dataSync.SyncPlayer(player, profile)

	return true, idsToRemove
end

function PetHandler.ToggleLock(player: Player, id: string)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end

	if profile.IsInTrade then
		return false
	end

	local pets = profile.Pets
	local index, petData = tblUtil.FindIndexWithId(pets, id)
	if not index then
		return false
	end

	petData.locked = not petData.locked
	local newState = petData.locked

	dataSync.SyncPlayer(player, profile)

	return true, newState
end

return PetHandler
