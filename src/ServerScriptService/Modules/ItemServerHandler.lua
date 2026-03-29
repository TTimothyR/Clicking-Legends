local ItemHandler = {};

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

local activePlayerBoost = {};

-- Modules
local playerData = require(script.Parent.Parent.DataModules.PlayerData);
local dataSync = require(script.Parent.Parent.DataModules.DataSyncServer);
local items = require(library.Items);

local function CheckBetterBoost(tbl, toCheck)
	local activeTier, _ = next(tbl)
	if not activeTier then activeTier = "" end
	return activeTier, activeTier > toCheck
end

local function GiveAllPotions(player: Player)
    local profile = playerData.GetData(player);
    local playerItems = profile.Items;
    local potions = playerItems.Potions;

    for tier, data in pairs(items.Potions) do
        for i, seperateData in ipairs(data.Buffs) do
            potions[seperateData[1]..'_'..tier] = 100;
        end
    end

    dataSync.SyncPlayer(player, profile);
end

function ItemHandler.UsePotion(player: Player, potionName: string, all: boolean)
    local profile = playerData.GetData(player);
    local playerItems = profile.Items;
    local potions = playerItems.Potions;
    local activePotions = profile.ActivePotions;

    if not potions[potionName] then return end;

    local amount = all and potions[potionName] or 1;
    potions[potionName] -= amount;
    if potions[potionName] == 0 then
        potions[potionName] = nil;
    end

    local nameSplit = string.split(potionName, '_');
    local buff, tier = nameSplit[1], nameSplit[2];

    local duration = items.Potions[tier].Duration * amount;
    local endTime = os.time() + duration;

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
			local endTime = activePotions[buff].Queued[tier].EndTime
			local newDuration = duration + initialDuration
			local newEndTime = endTime + duration
			
			local data = {EndTime = newEndTime, RemainingDuration = newDuration}
			activePotions[buff].Queued[tier] = data
		else
			local data = {EndTime = endTime, RemainingDuration = duration}
			activePotions[buff].Queued[tier] = data
		end
	else
		if currentActiveTier ~= "" and currentActiveTier ~= tier then
			-- local initialDuration = activePotions[buff].Active[currentActiveTier].RemainingDuration
			local initialEndTime = activePotions[buff].Active[currentActiveTier].EndTime
			local newDuration = endTime - os.time()
			
			local data = {EndTime = initialEndTime, RemainingDuration = newDuration}
			activePotions[buff].Active[currentActiveTier] = nil
			activePotions[buff].Queued[currentActiveTier] = data
			
			activePlayerBoost[player.UserId][buff] = {}
		end
		
		if activePotions[buff].Active[tier] then
			local initialDuration = activePotions[buff].Active[tier].RemainingDuration
			local endTime = activePotions[buff].Active[tier].EndTime
			local newDuration = duration + initialDuration
			local newEndTime = endTime + duration
			
			local data = {EndTime = newEndTime, RemainingDuration = newDuration}
			activePotions[buff].Active[tier] = data
			
			activePlayerBoost[player.UserId][buff] = {EndTime = newEndTime, Tier = tier}
		else
			local data = {EndTime = endTime, RemainingDuration = duration}
			activePotions[buff].Active[tier] = data
			
			activePlayerBoost[player.UserId][buff] = {EndTime = endTime, Tier = tier}
		end
	end

    dataSync.SyncPlayer(player, profile);
end

function ItemHandler.Initialize()
    for _, player: Player in ipairs(players:GetPlayers()) do
        GiveAllPotions(player);
    end

    players.PlayerAdded:Connect(function(player)
        GiveAllPotions(player);
    end)
end

return ItemHandler;