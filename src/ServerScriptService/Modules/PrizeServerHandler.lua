local PrizeHandler = {};

-- Services
local rs = game:GetService('ReplicatedStorage');
local sss = game:GetService('ServerScriptService')

-- Variables
local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');
local dataModules: Folder = sss:WaitForChild('DataModules');

-- Modules
local infMath = require(framework.InfiniteMath);
local prizes = require(library.Prizes);
local playerData = require(dataModules.PlayerData);
local rewardHandler = require(script.Parent.Private.RewardHandler);

local function CheckAlreadyClaimed(prizeData, prizeType, prizeIndex)
    for i, idx in ipairs(prizeData[prizeType]) do
        if idx == prizeIndex then
            return true;
        end
    end
    return false;
end

function PrizeHandler.ClaimPrize(player: Player, prizeType: string, prizeIndex: number)
    if prizeType ~= 'Eggs' and prizeType ~= 'ActualClicks' then
        return false, 'SERVER - Invalid Prize Type';
    end
    if prizes[prizeType][prizeIndex] == nil then
        return false, 'SERVER - Invalid Prize Index';
    end

    local profile = playerData.GetData(player);
    local prizeData = profile.ClaimedPrizes;

    if CheckAlreadyClaimed(prizeData, prizeType, prizeIndex) then
        return false;
    end

    local prizeStat = prizes[prizeType][prizeIndex];
    local target = infMath.new(prizeStat.Target);
    local currentProgress = infMath.new(profile[prizeType]);

    if currentProgress < target then
        return false;
    end

    local rewardData = prizeStat.Reward;
    if rewardData[1] == 'Pet' then
        local success, warning = rewardHandler.ClaimPet(player, rewardData[2], rewardData[3]);
        if not success then
            return false, warning;
        end
    elseif rewardData[1] == 'Currency' then
        local success, warning = rewardHandler.ClaimCurrency(player, rewardData[2], rewardData[3]);
        if not success then
            return false, warning;
        end
    elseif rewardData[1] == 'Perk' then
        local success, warning = rewardHandler.ClaimPerk(player, rewardData[2], rewardData[3]);
        if not success then
            return false, warning;
        end
    else
        return false, 'SERVER - Invalid Reward Type, unable to claim prize.';
    end

    table.insert(prizeData[prizeType], prizeIndex);

    print(prizeData)

    return true;
end

return PrizeHandler;