--!strict

local IndexHandler = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataModules = ServerScriptService:WaitForChild("DataModules")
local framework = ReplicatedStorage:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local playerData = require(dataModules.PlayerData)
local eggStats = require(library.EggStats)
local rewardHandler = require(script.Parent.Private.RewardHandler)

function IndexHandler.ClaimIndexReward(player: Player, eggName: string, shiny: boolean): boolean
	local profile = playerData.GetData(player)
	local claimedEggs = profile.ClaimedEggs
	local petIndex = profile.PetIndex

	local fullEggName = shiny and "Shiny " .. eggName or eggName

	if claimedEggs[fullEggName] then
		return false
	end

	for petName, _ in pairs(eggStats[eggName].Pets) do
		local fullPetName = shiny and "Shiny " .. petName or petName

		if not petIndex[fullPetName] then
			return false
		else
			continue
		end
	end

	local reward = shiny and eggStats[eggName].ShinyRewards or eggStats[eggName].Rewards

	for _, rewardData in ipairs(reward) do
		local rewardType = rewardData[1]
		local rewardName = rewardData[2]
		local amount = rewardData[3]

		if rewardType == "Currency" then
			rewardHandler.ClaimCurrency(player, rewardName, amount)
		elseif rewardType == "Potion" then
			rewardHandler.ClaimPotion(player, rewardName, amount)
		end
	end

	claimedEggs[fullEggName] = true

	return true
end

return IndexHandler
