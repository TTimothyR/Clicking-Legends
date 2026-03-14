local DataSync = {};

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework: Folder = rs:WaitForChild('Framework');

local lastSentData = {};

-- Modules
local network = require(framework.Network);
local infMath = require(framework.InfiniteMath);
local playerDataTemplate = require(rs.PlayerData);

-- Constants
local blackListedStats = {
    -- TradeRequestFrom = true,
    ClickDebounce = true,
}

local privateStats = {};
local infMathStats = {
    ActualClicks = true,
    Clicks = true,
    Gems = true,
    Rebirths = true
}

local function PackInfiniteMath(num)
    return {first = num.first, second = num.second};
end

local function PackData(data, includePrivate)
    local out = {};
    for key, value in pairs(data) do
        if blackListedStats[key] then continue end;
        if not includePrivate and privateStats[key] then continue end;

        if infMathStats[key] then
            out[key] = PackInfiniteMath(value);
        elseif type(value) == 'table' then
            if key == 'Pets' then
                local cloned = {};
                for i, pet in ipairs(value) do
                    cloned[i] = table.clone(pet);
                end
                out[key] = cloned;
            elseif key == 'ClaimedPrizes' then
                out[key] = {
                    Eggs = table.clone(value.Eggs);
                    ActualClicks = table.clone(value.ActualClicks);
                }
            else
                out[key] = table.clone(value);
            end
        else
            out[key] = value;
        end
    end
    
    return out;
end

local function CalculateDifference(old, new)
    local difference = {};
    local hasChanges = false;

    for key, newValue in pairs(new) do
        local oldValue = old[key];
        local changed = false;

        if infMathStats[key] then
            changed = (oldValue == nil) or (oldValue.first ~= newValue.first) or (oldValue.second ~= newValue.second);
        elseif key == 'Pets' then
            changed = (oldValue == nil) or (#oldValue ~= #newValue);
            if not changed then
                -- print('Pet amount not changed');
                for i, newPet in ipairs(newValue) do
                    local oldPet = oldValue[i];
                    if oldPet == nil then changed = true break end;
                    -- print('----------------------')
                    for statName, statValue in pairs(newPet) do
                        -- print(statName, oldPet[statName], statValue)
                        if oldPet[statName] ~= statValue then changed = true break end;
                    end
                    if not changed then
                        for statName in pairs(oldPet) do
                            -- print(statName, newPet[statName]);
                            if newPet[statName] == nil then changed = true break end;
                        end
                    end
                    if changed then break end;
                end
            end
        elseif type(newValue) == 'table' then
            if oldValue == nil then
                changed = true;
            else
                for k, v in pairs(newValue) do
                    if oldValue[k] ~= v then changed = true break end;
                end
                if not changed then
                    for k in pairs(oldValue) do
                        if newValue[k] == nil then changed = true break end;
                    end
                end
            end
        else
            changed = (oldValue ~= newValue);
        end

        if changed then
            difference[key] = newValue;
            hasChanges = true;
        end
    end

    for key in pairs(old) do
        if new[key] == nil then
            difference[key] = '__REMOVED__';
            hasChanges = true;
        end
    end

    return hasChanges and difference or nil;
end

function DataSync.InitializePlayer(player, data)
    local snapshot = PackData(data, true);
    lastSentData[player] = snapshot;
    network:FireClient(player, 'FullDataSync', snapshot);
end

function DataSync.SyncPlayer(player, data)
    local old = lastSentData[player];
    if not old then
        DataSync.InitializePlayer(player, data);
        return;
    end

    local snapshot = PackData(data, true);
    local difference = CalculateDifference(old, snapshot);

    if difference then
        lastSentData[player] = snapshot;
        network:FireClient(player, 'DataSyncDifference', difference);
    end
end

function DataSync.GetOtherDataSync(requestingPlayer, targetUserId)
    if type(targetUserId) ~= 'number' then return nil end;
    
    local targetPlayer: Player = players:GetPlayerByUserId(targetUserId);
    if not targetPlayer or targetPlayer == requestingPlayer then return nil end;

    local cache = lastSentData[targetPlayer];
    if not cache then return nil end;

    local out = {};
    for key, value in pairs(cache) do
        if not privateStats[key] and not blackListedStats[key] then
            out[key] = value;
        end
    end
    return out;
end

function DataSync.Initialize()
    players.PlayerRemoving:Connect(function(player, reason)
        lastSentData[player] = nil;
    end)
end

return DataSync;