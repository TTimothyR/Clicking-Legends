local ItemHandler = {}

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local activePlayerBoost = {}

-- Modules
local playerData = require(script.Parent.Parent.DataModules.PlayerData)
local dataSync = require(script.Parent.Parent.DataModules.DataSyncServer).Private
local items = require(library.Items)
local network = require(framework.Network)

local function GiveAllPotions(player: Player)
	local profile = playerData.GetData(player)
	local playerItems = profile.Items
	local potions = playerItems.Potions

	for tier, data in pairs(items.Potions) do
		for _, separateData in ipairs(data.Buffs) do
			potions[separateData[1] .. "_" .. tier] = 100
		end
	end

	dataSync.SyncPlayer(player, profile)
end

local function CheckBetterBoost(tbl, toCheck)
	local activeTier, _ = next(tbl)
	if not activeTier then
		activeTier = ""
	end
	return activeTier, activeTier > toCheck
end

local function GetBestTier(tbl)
	local bestTier = ""
	for tier, _ in pairs(tbl) do
		if tier > bestTier then
			bestTier = tier
		end
	end
	return bestTier
end

local function LoadPotions(player: Player)
	local profile = playerData.GetData(player)
	local activePotions = profile.ActivePotions

	activePlayerBoost[player.UserId] = {}

	for boostType, tiers in pairs(activePotions) do
		local tier, data = next(tiers.Active)

		if tier and data then
			local remainingTime = data.RemainingDuration
			local currentTime = os.time()
			local endTime = currentTime + remainingTime

			activePotions[boostType].Active[tier] = { EndTime = endTime, RemainingDuration = remainingTime }
			activePlayerBoost[player.UserId][boostType] = { EndTime = endTime, Tier = tier }
		end
	end
	dataSync.SyncPlayer(player, profile)

	network:FireClient(player, "UpdateActivePotions")
end

local function EndPotion(player: Player, boostType)
	local profile = playerData.GetData(player)
	local activePotions = profile.ActivePotions

	activePotions[boostType].Active = {}
	activePlayerBoost[player.UserId][boostType] = nil

	local queue = activePotions[boostType].Queued
	local bestQueued = GetBestTier(queue)

	if bestQueued ~= "" then
		local data = queue[bestQueued]
		local remainingTime = data.RemainingDuration
		local currentTime = os.time()
		local endTime = currentTime + remainingTime

		activePotions[boostType].Active[bestQueued] = { EndTime = endTime, RemainingDuration = remainingTime }
		activePotions[boostType].Queued[bestQueued] = nil
		activePlayerBoost[player.UserId][boostType] = { EndTime = endTime, Tier = bestQueued }
	end
	dataSync.SyncPlayer(player, profile)

	network:FireClient(player, "UpdateActivePotions")
end

local function StartBoostController()
	task.spawn(function()
		while true do
			task.wait(1)
			local currentTime = os.time()
			for userId, boostData in pairs(activePlayerBoost) do
				local player = players:GetPlayerByUserId(userId)
				for boostType, data in pairs(boostData) do
					if data and data.EndTime then
						local endTime = data.EndTime
						if currentTime >= endTime then
							EndPotion(player, boostType)
						end
					else
						boostData[boostType] = nil
					end
				end
			end
		end
	end)
end

function ItemHandler.UsePotion(player: Player, potionName: string, all: boolean)
	local profile = playerData.GetData(player)
	local playerItems = profile.Items
	local potions = playerItems.Potions
	local activePotions = profile.ActivePotions

	if not potions[potionName] then
		return
	end

	local amount = all and potions[potionName] or 1
	potions[potionName] -= amount
	if potions[potionName] == 0 then
		potions[potionName] = nil
	end

	local nameSplit = string.split(potionName, "_")
	local buff, tier = nameSplit[1], nameSplit[2]

	local duration = items.Potions[tier].Duration * amount
	local endTime = os.time() + duration

	if not activePotions[buff] then
		activePotions[buff] = {}
		activePotions[buff]["Active"] = {}
		activePotions[buff]["Queued"] = {}
	end

	if not activePlayerBoost[player.UserId] then
		activePlayerBoost[player.UserId] = {}
	end

	if not activePlayerBoost[player.UserId][buff] then
		activePlayerBoost[player.UserId][buff] = {}
	end

	local currentActiveTier, better = CheckBetterBoost(activePotions[buff].Active, tier)

	if better then
		if activePotions[buff].Queued[tier] then
			local initialDuration = activePotions[buff].Queued[tier].RemainingDuration
			endTime = activePotions[buff].Queued[tier].EndTime
			local newDuration = duration + initialDuration
			local newEndTime = endTime + duration

			local data = { EndTime = newEndTime, RemainingDuration = newDuration }
			activePotions[buff].Queued[tier] = data
		else
			local data = { EndTime = endTime, RemainingDuration = duration }
			activePotions[buff].Queued[tier] = data
		end
	else
		if currentActiveTier ~= "" and currentActiveTier ~= tier then
			-- local initialDuration = activePotions[buff].Active[currentActiveTier].RemainingDuration
			local initialEndTime = activePotions[buff].Active[currentActiveTier].EndTime
			local newDuration = endTime - os.time()

			local data = { EndTime = initialEndTime, RemainingDuration = newDuration }
			activePotions[buff].Active[currentActiveTier] = nil
			activePotions[buff].Queued[currentActiveTier] = data

			activePlayerBoost[player.UserId][buff] = {}
		end

		if activePotions[buff].Active[tier] then
			local initialDuration = activePotions[buff].Active[tier].RemainingDuration
			endTime = activePotions[buff].Active[tier].EndTime
			local newDuration = duration + initialDuration
			local newEndTime = endTime + duration

			local data = { EndTime = newEndTime, RemainingDuration = newDuration }
			activePotions[buff].Active[tier] = data

			activePlayerBoost[player.UserId][buff] = { EndTime = newEndTime, Tier = tier }
		else
			local data = { EndTime = endTime, RemainingDuration = duration }
			activePotions[buff].Active[tier] = data

			activePlayerBoost[player.UserId][buff] = { EndTime = endTime, Tier = tier }
		end
	end

	dataSync.SyncPlayer(player, profile)
	network:FireClient(player, "UpdateActivePotions")
end

function ItemHandler.Initialize()
	for _, player: Player in ipairs(players:GetPlayers()) do
		GiveAllPotions(player)
		task.spawn(LoadPotions, player)
	end

	players.PlayerAdded:Connect(function(player)
		GiveAllPotions(player)
		task.spawn(LoadPotions, player)
	end)
	players.PlayerRemoving:Connect(function(player, _)
		activePlayerBoost[player.UserId] = nil
	end)
	StartBoostController()
end

return ItemHandler
