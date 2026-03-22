local UpgradeHandler = {};

-- Services
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

-- Modules
local playerData = require(script.Parent.Parent.DataModules.PlayerData);
local dataSync = require(script.Parent.Parent.DataModules.DataSyncServer);
local upgrades = require(library.Upgrades);
local globals = require(framework.Globals);
local infMath = require(framework.InfiniteMath);

local upgradeCallbacks = {   
    ['More Egg Opens'] = function(profile, upgradeName: string)
        profile.EggHatches += upgrades[upgradeName].Increment;
    end,
    ['More Pet Slots'] = function(profile, upgradeName: string)
        profile.PetStorage += upgrades[upgradeName].Increment;
    end,
    ['More Luck'] = function(profile, upgradeName: string)
        profile.LuckPercentage += upgrades[upgradeName].Increment;
    end,
    ['More Pets'] = function(profile, upgradeName: string)
        profile.PetEquips += upgrades[upgradeName].Increment;
    end,
}

function UpgradeHandler.AddUpgradesToData(player: Player)
    local profile = playerData.GetData(player);
    for upgradeName, _ in pairs(upgrades) do
        if not profile.UpgradeLevels[upgradeName] then
            profile.UpgradeLevels[upgradeName] = 0;
        end
    end
end

function UpgradeHandler.BuyUpgrade(player: Player, upgradeName: string)
    if not upgrades[upgradeName] then
        return;
    end
    
    local profile = playerData.GetData(player);
    if not profile then return end;

    local upgradeLevels = profile.UpgradeLevels;
    if upgradeLevels[upgradeName] == upgrades[upgradeName].Maximum then
        return;
    end

    local cost = infMath.new(upgrades[upgradeName].BasePrice * math.pow(globals.UpgradeMultiplier, upgradeLevels[upgradeName]));

    if profile.Gems < cost then
        return;
    end

    profile.Gems = infMath.new(profile.Gems - cost)
    player.leaderstats.Gems.Value = profile.Gems:GetSuffix(true);

    if upgradeCallbacks[upgradeName] then
        upgradeCallbacks[upgradeName](profile, upgradeName);
    end

    profile.UpgradeLevels[upgradeName] += 1;

    dataSync.SyncPlayer(player, profile);
end

return UpgradeHandler;