local StatHandler = {};

-- Services
local players = game:GetService('Players');
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local framework: Folder = rs:WaitForChild('Framework');

-- Modules
local playerData = require(dataModules.PlayerData);
local infMath = require(framework.InfiniteMath);
local network = require(framework.Network);

local function sendStatsToClient(player: Player)
    local profile = playerData.GetData(player);

    network:FireClient(player, 'LoadStatDisplay', profile);
end

function StatHandler.Click(player: Player, debounce: number)
    local profile = playerData.GetData(player);

    if not profile or profile.ClickDebounce then return end;

    profile.ClickDebounce = true;

    local increment = 1;

    profile.Clicks = infMath.new(profile.Clicks + increment);
    player.leaderstats.Clicks.Value = infMath.new(profile.Clicks):GetSuffix(true);

    local waitTime = debounce ~= nil and debounce or .15;

    task.delay(waitTime, function()
        profile.ClickDebounce = false;
    end)
end

function StatHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    for _, player: Player in ipairs(players:GetPlayers()) do
        sendStatsToClient(player);
    end

    players.PlayerAdded:Connect(function(player: Player)
        sendStatsToClient(player);
    end)
end

return StatHandler;