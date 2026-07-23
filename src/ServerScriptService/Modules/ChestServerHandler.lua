local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService.DataModules.PlayerData)
local RewardHandler = require(ServerScriptService.Modules.Private.RewardHandler)
local Chests = require(ReplicatedStorage.Framework.Library.Chests)
local GetRandomItem = require(ReplicatedStorage.Framework.Shared.GetRandomItem)
local ChestHandler = {}

function ChestHandler.ClaimChest(player: Player, chestName: string)
	if not Chests[chestName] then
		return
	end

	local profile = PlayerData.GetData(player)
	if not profile then
		return
	end

	if chestName == "VIPChest" then
		if not profile.OwnedGamepasses["VIP"] then
			return
		end
	end

	local lastClaimed = profile.Chests[chestName].LastClaimed

	if lastClaimed + Chests[chestName].RespawnTime > os.time() then
		return
	end

	profile.Chests[chestName].LastClaimed = os.time()

	local actualItemPool = {}
	for itemName, data in pairs(Chests[chestName].ItemPool) do
		actualItemPool[itemName] = data[2]
	end

	local items = {}
	for _ = 1, Chests[chestName].Rolls do
		local item = GetRandomItem(actualItemPool)
		if not items[item] then
			items[item] = 1
		else
			items[item] += 1
		end
	end

	for itemName, amount in pairs(items) do
		local itemType = Chests[chestName].ItemPool[itemName][1]
		if itemType == "Potions" then
			RewardHandler.ClaimPotion(player, itemName, amount)
		elseif itemType == "Pets" then
			for _ = 1, amount do
				RewardHandler.ClaimPet(player, itemName, (string.find(itemName, "Shiny") ~= nil), "")
			end
		end
	end
end

function ChestHandler.Initialize()
	local function OnPlayerAdded(player: Player)
		local profile = PlayerData.GetData(player)
		if not profile then
			return
		end

		for chestName, _ in pairs(Chests) do
			if not profile.Chests[chestName] then
				profile.Chests[chestName] = { LastClaimed = 0 }
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		OnPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		OnPlayerAdded(player)
	end)
end

return ChestHandler
