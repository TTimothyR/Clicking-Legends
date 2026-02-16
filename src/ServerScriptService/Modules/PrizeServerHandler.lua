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

local function CheckAlreadyClaimed(prizeData, prizeType, prizeIndex)
    for i, idx in ipairs(prizeData[prizeType]) do
        if idx == prizeIndex then
            return true;
        end
    end
    return false;
end

function PrizeHandler.ClaimPrize(player: Player, prizeType: string, prizeIndex: number)
    if prizeType ~= 'Eggs' or prizeType ~= 'ActualClicks' then
        return false;
    end

    if prizes[prizeType][prizeIndex] == nil then
        return false;
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

    table.insert(prizeData[prizeType], prizeIndex);

    return true;
end

return PrizeHandler;