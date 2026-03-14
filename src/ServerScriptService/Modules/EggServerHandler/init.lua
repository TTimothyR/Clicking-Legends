local EggHandler = {}

-- Services
local players = game:GetService('Players')
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
local dataSync = require(dataModules.DataSyncServer);

-- Bindables
local NotifyHatch = game:GetService("ServerStorage"):WaitForChild("NotifyHatch")
local HatchBind = game:GetService('ServerStorage'):WaitForChild('Hatch');

local function ValidateDistance(player: Player, eggName: string)
    local maxDistance = 15;

    local view = workspace.Eggs[eggName].View;

    local distance = (player.Character.HumanoidRootPart.Position - view.Position).Magnitude;
    return distance <= maxDistance;
end

function EggHandler.ToggleAutoHatch(player: Player, eggName: string, new: boolean)
    local profile = playerData.GetData(player);
    if not profile then return end;
    profile.IsAutoHatching = new;
    profile.TargetAutoHatchEgg = eggName;
    
    if profile.IsAutoHatching then
        EggHandler.OpenEgg(player, eggName, profile.EggHatches);
    end

    dataSync.SyncPlayer(player, profile);
end

function EggHandler.OpenEgg(player: Player, eggName: string, amount: number)
    if not ValidateDistance(player, eggName) then
        EggHandler.ToggleAutoHatch(player, '', false);
        print('Too far away from egg.')
        network:FireClient(player, 'UnableToOpen', 'You are too far away from the egg.');
        return
    end
    if not eggStats[eggName] then
        EggHandler.ToggleAutoHatch(player, '', false);
        warn('Invalid egg name', eggName);
        network:FireClient(player, 'UnableToOpen', 'Invalid egg name, please report this to a developer.');
        return;
    end

    local profile = playerData.GetData(player);
    if not profile then
        EggHandler.ToggleAutoHatch(player, '', false);
        warn('Could not fetch profile for player', player.Name)
        network:FireClient(player, 'UnableToOpen', 'Failed to get profile, please report this to a developer.');
        return;
    end

    if profile.HatchDebounce then
        print('Hatching on cooldown.');
        return;
    end

    local clicks = infMath.new(profile.Clicks);
    local priceForOne = infMath.new(eggStats[eggName].Price[2]);
    local price = infMath.new(priceForOne * amount);

    if clicks < price then
        local newAmount = math.floor(infMath.new(clicks/priceForOne):Reverse());
        if newAmount > 0 then
            amount = newAmount
            price = infMath.new(priceForOne * amount);
        else
            EggHandler.ToggleAutoHatch(player, '', false);
            warn('Not enough currency');
            network:FireClient(player, 'UnableToOpen', 'You do not have enough currency to afford this egg.');
            return;
        end
    end

    profile.HatchDebounce = true;

    profile.Clicks = infMath.new(profile.Clicks - price);
    player.leaderstats.Clicks.Value = profile.Clicks:GetSuffix(true);
   
    profile.Eggs = infMath.new(profile.Eggs + amount);
    player.leaderstats.Eggs.Value = profile.Eggs:GetSuffix(true);

    -- player:SetAttribute('Clicks', http:JSONEncode(profile.Clicks));
    -- player:SetAttribute('Eggs', http:JSONEncode(profile.Eggs));

    local petData = {};
    local changes = {};

    for _ = 1, amount do
        local petName, shiny = luckHandler.RollPet(player, eggName);
        local rarity = petStats[petName].Rarity;
        local fullName = shiny and 'Shiny '..petName or petName;
        local id = generateID.NewID();

        local autoDeleted = profile.AutoDeletedPets[petName];
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

        if not autoDeleted then
            -- if petStats[petName].Secret then
            --     NotifyHatch:Invoke(player.Name, petName, 'Secret');
            -- end
            table.insert(changes, {
                petName = petName,
                rarity = rarity,
                isSecret = petStats[petName].Secret == true;
                isShiny = shiny,
                delta = 1
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

    end

    if #changes > 0 then
        task.spawn(function()
            local encoded = http:JSONEncode(changes);
            print(encoded)
            HatchBind:Invoke(player.Name, encoded);
        end)
    end
    
    player.UILock.Value = true;
    dataSync.SyncPlayer(player, profile);
    network:FireClient(player, 'EggAnimation', eggName, amount, petData);
end

function EggHandler.RequestNextHatch(player: Player)
    local profile = playerData.GetData(player);
    if not profile or not profile.IsAutoHatching then return end;
    if player.UILock.Value then return end;

    task.delay(0.3, function()
        EggHandler.OpenEgg(player, profile.TargetAutoHatchEgg, profile.EggHatches);
    end)
end

function EggHandler.ResetVariables(player: Player, startUp: boolean)
    startUp = startUp == nil and false or startUp;
    
    local profile = playerData.GetData(player);
    if not profile then warn("Could not fetch profile.") return end
    player.UILock.Value = false;
    profile.HatchDebounce = false;
    if startUp then
        profile.IsAutoHatching = false;
        profile.TargetAutoHatchEgg = '';
    end
    dataSync.SyncPlayer(player, profile);
end

function EggHandler.Initialize()
    for _, player: Player in ipairs(players:GetPlayers()) do
        task.spawn(EggHandler.ResetVariables, player, true);
    end
    players.PlayerAdded:Connect(function(player)
        task.spawn(EggHandler.ResetVariables, player, true);
    end)
end

return EggHandler