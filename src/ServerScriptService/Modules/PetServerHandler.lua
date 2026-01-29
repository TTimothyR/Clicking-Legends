local PetHandler = {};

-- Services
local players = game:GetService('Players');
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local framework: Folder = rs:WaitForChild('Framework');

-- Modules
local playerData = require(dataModules.PlayerData);
local tblUtil = require(framework.TableUtility);
local network = require(framework.Network);
local globals = require(framework.Globals);

function PetHandler.LevelUp(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return end;

    local pets = profile.Pets;
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return end;

    local xpNeeded = globals.XPForNextLevel(petData.level, petData.shiny);
    if petData.xp >= xpNeeded then
        petData.xp = 0;
        petData.level += 1;
    end
end

function PetHandler.EquipPet(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePets', player, petData, true);
    end

    petData.equipped = true;
    return true;
end

function PetHandler.UnequipPet(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePets', player, petData, false);
    end

    petData.equipped = false;
    return true;
end

return PetHandler