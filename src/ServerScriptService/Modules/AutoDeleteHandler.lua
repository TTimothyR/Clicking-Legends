local AutoDeleteHandler = {};

-- Services
local sss = game:GetService('ServerScriptService');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');

-- Modules
local playerData = require(dataModules.PlayerData);

function AutoDeleteHandler.ToggleAutoDelete(player: Player, petName: string)
    local profile = playerData.GetData(player);
    if not profile then return end

    if profile.AutoDeletedPets[petName] then
        profile.AutoDeletedPets[petName] = nil;
        return false;
    else
        profile.AutoDeletedPets[petName] = true;
        return true;
    end
end

function AutoDeleteHandler.GetAutoDeleted(player: Player, petName: string)
    local profile = playerData.GetData(player);
    if not profile then return end;

    if profile.AutoDeletedPets[petName] then
        return true;
    else
        return false;
    end
end

return AutoDeleteHandler;