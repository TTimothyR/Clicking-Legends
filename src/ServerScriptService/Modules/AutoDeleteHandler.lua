local AutoDeleteHandler = {};

-- Services
local sss = game:GetService('ServerScriptService');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');

-- Modules
local playerData = require(dataModules.PlayerData);
local dataSync = require(dataModules.DataSyncServer);

function AutoDeleteHandler.ToggleAutoDelete(player: Player, petName: string)
    local profile = playerData.GetData(player);
    if not profile then return end

    local returnValue: boolean

    if profile.AutoDeletedPets[petName] then
        profile.AutoDeletedPets[petName] = nil;
        returnValue = false;
    else
        profile.AutoDeletedPets[petName] = true;
        returnValue = true;
    end

    dataSync.SyncPlayer(player, profile);

    return returnValue
end

return AutoDeleteHandler;