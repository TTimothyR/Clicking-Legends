local RewardHandler = {};

-- Services
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');
local http = game:GetService('HttpService')

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local assets: Folder = rs:WaitForChild('Assets');
local petModels: Folder = assets:WaitForChild('PetModels');
local framework: Folder = rs:WaitForChild('Framework');

-- Modules
local playerData = require(dataModules.PlayerData);
local generateID = require(framework.GenerateID);
local infMath = require(framework.InfiniteMath);


function RewardHandler.ClaimPet(player: Player, petName: string, shiny: boolean)
    local profile = playerData.GetData(player);

    local fullName: string = shiny and 'Shiny '..petName or petName;

    if not petModels:FindFirstChild(fullName) then
        return false, 'SERVER - Invalid pet name, unable to claim prize.';
    end

    local pets = profile.Pets;
    local id = generateID.NewID();

    table.insert(pets,{
        petName = petName,
        fullName = fullName,
        shiny = shiny,
        id = id,
        level = 1,
        xp = 0,
        date = os.time(),
        locked = false,
        equipped = false
    })

    return true;
end

function RewardHandler.ClaimCurrency(player: Player, currencyStr: string, amount: number)
    local profile = playerData.GetData(player);
    
    if not profile[currencyStr] then
        return false, 'SERVER - Invalid currency string, unable to claim prize.';
    end

    local currentValue = infMath.new(profile[currencyStr]);
    local increment = infMath.new(amount);
    profile[currencyStr] = infMath.new(currentValue + increment);

    -- if player:GetAttribute(currencyStr) then
    --     player:SetAttribute(currencyStr, http:JSONEncode(profile[currencyStr]));
    -- end
    for _, instance in ipairs(player:GetDescendants()) do
        if instance.Name == currencyStr then
            instance.Value = profile[currencyStr]:GetSuffix(true);
        end
    end

    return true;
end

function RewardHandler.ClaimPerk(player: Player, perkStr: string, amount: number)
    local profile = playerData.GetData(player);

    if not profile[perkStr] then
        return false, 'SERVER - Perk not found, unable to claim prize.';
    end

    profile[perkStr] += amount;

    return true;
end

return RewardHandler;