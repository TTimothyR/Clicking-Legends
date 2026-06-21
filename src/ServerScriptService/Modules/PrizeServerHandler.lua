local PrizeHandler = {}

-- Services
local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local dataModules = sss:WaitForChild("DataModules")

-- Modules
local infMath = require(framework.InfiniteMath)
local prizes = require(library.Prizes)
local playerData = require(dataModules.PlayerData)
local rewardHandler = require(script.Parent.Private.RewardHandler)
local dataSync = require(dataModules.DataSyncServer)

local function CheckAlreadyClaimed(prizeData, prizeType, prizeIndex)
	for _, idx in ipairs(prizeData[prizeType]) do
		if idx == prizeIndex then
			return true
		end
	end
	return false
end

function PrizeHandler.ClaimPrize(player: Player, prizeType: string, prizeIndex: number)
	if prizeType ~= "Eggs" and prizeType ~= "ActualClicks" then
		return "SERVER - Invalid Prize Type"
	end
	if prizes[prizeType][prizeIndex] == nil then
		return "SERVER - Invalid Prize Index"
	end

	local profile = playerData.GetData(player)
	local prizeData = profile.ClaimedPrizes

	if CheckAlreadyClaimed(prizeData, prizeType, prizeIndex) then
		return
	end

	local prizeStat = prizes[prizeType][prizeIndex]
	local target = infMath.new(prizeStat.Target)
	local currentProgress = infMath.new(profile[prizeType])

	if currentProgress < target then
		return
	end

	local rewardData = prizeStat.Reward
	if rewardData[1] == "Pet" then
		local success, warning = rewardHandler.ClaimPet(player, rewardData[2], rewardData[3])
		if not success then
			return warning
		end
	elseif rewardData[1] == "Currency" then
		local success, warning = rewardHandler.ClaimCurrency(player, rewardData[2], rewardData[3])
		if not success then
			return warning
		end
	elseif rewardData[1] == "Perk" then
		local success, warning = rewardHandler.ClaimPerk(player, rewardData[2], rewardData[3])
		if not success then
			return warning
		end
	else
		return "SERVER - Invalid Reward Type, unable to claim prize."
	end

	table.insert(prizeData[prizeType], prizeIndex)

	dataSync.SyncPlayer(player, profile)

	return
end

return PrizeHandler
