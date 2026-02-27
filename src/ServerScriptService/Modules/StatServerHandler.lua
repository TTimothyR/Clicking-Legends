local StatHandler = {};

-- Services
local players = game:GetService('Players');
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');
local http = game:GetService('HttpService');
local physicsService = game:GetService('PhysicsService');


-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local framework: Folder = rs:WaitForChild('Framework');
local library: Folder = framework:WaitForChild('Library');

local characterGroup = "CHAR";
local debrisGroup = 'DEBRIS';

local rng = Random.new();

-- Modules
local playerData = require(dataModules.PlayerData);
local infMath = require(framework.InfiniteMath);
local network = require(framework.Network);
local petStats = require(library.PetStats);
local globals = require(framework.Globals);
local petHandler = require(script.Parent.PetServerHandler);
local dataSync = require(dataModules.DataSyncServer);

-- Constants
local clickDebounce = 0.15;

local function SetupCollision()
    pcall(function()
        physicsService:RegisterCollisionGroup(characterGroup);
    end)    
    pcall(function()
        physicsService:RegisterCollisionGroup(debrisGroup);
    end)

    physicsService:CollisionGroupSetCollidable(characterGroup, debrisGroup, false);
    physicsService:CollisionGroupSetCollidable(debrisGroup, debrisGroup, false);
end

local function GetPetClicks(pets)
    local totalClicks = 0

    for _, petData in ipairs(pets) do
        if not petData.equipped then continue end
        totalClicks += globals.GetPetClicks(petData);
    end

    return totalClicks;
end

function StatHandler.Click(player: Player)
    local profile = playerData.GetData(player);

    if not profile or profile.ClickDebounce then return end;

    profile.ClickDebounce = true;

    task.spawn(function()
        for _, petData in ipairs(profile.Pets) do
            if petData.equipped and petData.level < 50 then
                petData.xp += 1;
                local xpForNextLevel = globals.XPForNextLevel(petData.level, petData.shiny)

                if petData.xp >= xpForNextLevel then
                    petHandler.LevelUp(player, petData.id);
                end
            end
        end
    end)

    local petIncrement = GetPetClicks(profile.Pets);
    local increment = infMath.new((100+petIncrement) * profile.Rebirths);

    local criticalRoll = rng:NextInteger(1, 25);
    local critical = false;
    if criticalRoll == 1 then
        increment *= 1.5;
        critical = true;
    end

    profile.Clicks = infMath.new(profile.Clicks + increment);
    player.leaderstats.Clicks.Value = infMath.new(profile.Clicks):GetSuffix(true);
    profile.ActualClicks = infMath.new(profile.ActualClicks + infMath.new(1));

    -- player:SetAttribute("Clicks", http:JSONEncode(profile.Clicks));
    -- player:SetAttribute("ActualClicks", http:JSONEncode(profile.ActualClicks));

    task.delay(clickDebounce, function()
        profile.ClickDebounce = false;
    end)

    dataSync.SyncPlayer(player, profile);

    return increment, critical
end

function StatHandler.ToggleAutoClicker(player: Player)
    local profile = playerData.GetData(player);
    if not profile then return false end;

    profile.AutoClickerStatus = not profile.AutoClickerStatus;
    dataSync.SyncPlayer(player, profile);
end

function StatHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    SetupCollision();
end

return StatHandler;