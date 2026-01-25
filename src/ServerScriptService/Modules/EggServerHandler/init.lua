local EggHandler = {}

-- Services
local rs = game:GetService('ReplicatedStorage');
local sss = game:GetService('ServerScriptService');
local http = game:GetService('HttpService');

-- Variables
local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');
local dataModules: Folder = sss:WaitForChild('DataModules');

-- Modules
local eggStats = require(library.EggStats);
local petStats = require(library.PetStats);
local playerData = require(dataModules.PlayerData);
local infMath = require(framework.InfiniteMath);
local generateID = require(framework.GenerateID);
local network = require(framework.Network);
local luckHandler = require(script.Parent.LuckHandler);

function EggHandler.OpenEgg(player: Player, eggName: string, amount: number)
    if not eggStats[eggName] then
        warn('Invalid egg name', eggName);
        return;
    end

    local profile = playerData.GetData(player);
    if not profile then
        warn('Could not fetch profile for player', player.Name)
        return;
    end

    local clicks = infMath.new(profile.Clicks);
    local price = infMath.new(eggStats[eggName].Price[2] * amount);

    if clicks < price then
        warn('Not enough currency');
        return;
    end

    profile.Clicks = infMath.new(profile.Clicks - price);
    player.leaderstats.Clicks.Value = profile.Clicks:GetSuffix(true);
   
    profile.Eggs = infMath.new(profile.Eggs + amount);
    player.leaderstats.Eggs.Value = profile.Eggs:GetSuffix(true);

    player:SetAttribute('Clicks', http:JSONEncode(profile.Clicks));

    local petData = {};

    for _ = 1, amount do
        local petName, shiny = luckHandler.RollPet(player, eggName);
        local rarity = petStats[petName].Rarity;
        local fullName = shiny and 'Shiny '..petName or petName;
        local id = generateID.NewID();

        local autoDeleted = false;
        local new = false;

        if not profile.PetIndex[fullName] then
            profile.PetIndex[fullName] = true;
            new = true;
            autoDeleted = false;
        end

        table.insert(petData, {
            petName = petName,
            fullName = fullName,
            rarity = rarity,
            shiny = shiny,
            autoDeleted = autoDeleted,
            new = new,
        })

        table.insert(profile.Pets,{
            petName = petName,
            fullName = fullName,
            shiny = shiny,
            id = id,
            level = 1,
            xp = 0,
            date = os.time();
            locked = false,
            equipped = false,
        })
    end
    network:FireClient(player, 'EggAnimation', eggName, amount, petData);
end

return EggHandler