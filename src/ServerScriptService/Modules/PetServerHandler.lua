local PetHandler = {};

-- Services
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local framework: Folder = rs:WaitForChild('Framework');

-- Modules
local playerData = require(dataModules.PlayerData);
local tblUtil = require(framework.TableUtility);

function PetHandler.EquipPet(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    petData.equipped = true;
    return true;
end

function PetHandler.UnequipPet(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    petData.equipped = false;
    return true;
end

return PetHandler