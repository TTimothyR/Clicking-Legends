local RebirthHandler = {};

-- Services
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');
local http = game:GetService('HttpService');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');

-- Modules
local playerData = require(dataModules.PlayerData);
local rebirthStats = require(library.RebirthStats);
local petStats = require(library.PetStats);
local infMath = require(framework.InfiniteMath);
local globals = require(framework.Globals);
local dataSync = require(dataModules.DataSyncServer);

local function GetPetGems(pets)
    local totalGems = 0

    for _, petData in ipairs(pets) do
        if not petData.equipped then continue end
        totalGems += globals.GetPetGems(petData)
    end
    return totalGems;
end

function RebirthHandler.AttemptRebirth(player: Player, rebirthIndex: number)
    local profile = playerData.GetData(player);

    local rebirthAmount = rebirthStats[rebirthIndex];

    local clicks = infMath.new(profile.Clicks);
    local rebirths = infMath.new(profile.Rebirths);
    local price = infMath.new(globals.RebirthBasePrice * rebirthAmount * rebirths);

    local petGems = GetPetGems(profile.Pets);
    local gemsPerRebirth = petGems < 1 and 10 or 10 * petGems;

    if clicks >= price then
        if profile.OwnedGamepasses['Double Rebirths'] then
            rebirthAmount *= 2;
        end
        if profile.OwnedGamepasses['Double Gems'] then
            gemsPerRebirth *= 2;
        end
        profile.Clicks = infMath.new(0);
        -- player:SetAttribute('Clicks', http:JSONEncode(profile.Clicks));
        player.leaderstats.Clicks.Value = profile.Clicks:GetSuffix(true);

        profile.Gems = infMath.new(profile.Gems + (gemsPerRebirth * rebirthAmount));
        -- player:SetAttribute('Gems', http:JSONEncode(profile.Gems));
        player.leaderstats.Gems.Value = profile.Gems:GetSuffix(true);
        profile.Rebirths = infMath.new(profile.Rebirths + rebirthAmount);
        -- player:SetAttribute('Rebirths', http:JSONEncode(profile.Rebirths));
        player.leaderstats.Rebirths.Value = profile.Rebirths:GetSuffix(true);
    
        dataSync.SyncPlayer(player, profile);
    end
end

function RebirthHandler.ToggleAutoRebirth(player: Player)
    local profile = playerData.GetData(player);
    if not profile then return end;

    profile.AutoRebirthStatus = not profile.AutoRebirthStatus;
    dataSync.SyncPlayer(player, profile);
end

function RebirthHandler.SetAutoRebirthIndex(player: Player, rebirthIndex: number)
    local profile = playerData.GetData(player);
    if not profile then return end

    if rebirthIndex == profile.AutoRebirthIndex then
        profile.AutoRebirthIndex = 0;
    else
        profile.AutoRebirthIndex = rebirthIndex;
    end

    dataSync.SyncPlayer(player, profile);
end

return RebirthHandler;