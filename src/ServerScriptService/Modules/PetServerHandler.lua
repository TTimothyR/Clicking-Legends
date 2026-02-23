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
local generateID = require(framework.GenerateID)

local function GetPetAmount(profile, petName: string)
    local count = 0;
    for i, petData in ipairs(profile.Pets) do
        if petData.petName == petName and not petData.shiny and not petData.locked then
            count += 1
        end
    end
    return count;
end

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

    if profile.CurrentEquips == profile.PetEquips then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePet', player, petData, true);
    end

    petData.equipped = true;
    profile.CurrentEquips += 1;
    return true;
end

function PetHandler.EquipBest(player: Player)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets

    local statTable = {};

    for _, petData in ipairs(pets) do
        if petData.equipped then
            petData.equipped = false;
            profile.CurrentEquips -= 1;
        end

        table.insert(statTable, {petData = petData, Clicks = globals.GetPetClicks(petData)});
    end

    table.sort(statTable, function(a,b)
        return a.Clicks > b.Clicks;
    end)

    for i = 1, profile.PetEquips do
        local petData = statTable[i].petData;
        petData.equipped = true;
        profile.CurrentEquips += 1;
    end
    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePets', player);
    end

    return true;
end

function PetHandler.UnequipAll(player: Player)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets
    for _, petData in ipairs(pets) do
        petData.equipped = false;
        profile.CurrentEquips -= 1;
    end

    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePets', player);
    end

    return true;
end

function PetHandler.UnequipPet(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePet', player, petData, false);
    end

    petData.equipped = false;
    profile.CurrentEquips -= 1;
    return true;
end

function PetHandler.DeletePet(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    if profile.IsInTrade then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    if petData.locked then return false end;

    if petData.equipped then
        PetHandler.UnequipPet(player, id);
    end
    table.remove(pets, index);

    return true;
end

function PetHandler.MakeShiny(player: Player, petName: string)
    local profile = playerData.GetData(player);
    if not profile then return false, nil end;

    if profile.IsInTrade then return false, nil end;
    if GetPetAmount(profile, petName) < 8 then return false, nil end;

    local idsToRemove = {};
    local pets = profile.Pets

    local count = 0
    for _, petData in ipairs(pets) do
        if count == 8 then break end;
        if petData.petName == petName and not petData.shiny and not petData.locked then
            table.insert(idsToRemove, petData.id);
            count += 1
        end
    end

    for _, id in ipairs(idsToRemove) do
        local index, petData = tblUtil.FindIndexWithId(pets, id);
        if petData.equipped then
            profile.CurrentEquips -= 1;
        end
        table.remove(pets, index);
    end
    for _, plr: Player in ipairs(players:GetPlayers()) do
        network:FireClient(plr, 'UpdatePet', player);
    end

    table.insert(pets, {
        petName = petName,
        fullName = 'Shiny '..petName,
        shiny = true,
        id = generateID.NewID(),
        level = 1,
        xp = 0,
        date = os.time(),
        locked = false,
        equipped = false
    })

    return true, idsToRemove;
end

function PetHandler.ToggleLock(player: Player, id: string)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    if profile.IsInTrade then return false end;

    local pets = profile.Pets
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return false end;

    petData.locked = not petData.locked;
    local newState = petData.locked

    return true, newState;
end

return PetHandler