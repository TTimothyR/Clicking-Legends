local StatHandler = {};

-- Services
local players = game:GetService('Players');
local sss = game:GetService('ServerScriptService');
local rs = game:GetService('ReplicatedStorage');
local http = game:GetService('HttpService');

-- Variables
local dataModules: Folder = sss:WaitForChild('DataModules');
local framework: Folder = rs:WaitForChild('Framework');

-- Modules
local playerData = require(dataModules.PlayerData);
local infMath = require(framework.InfiniteMath);
local network = require(framework.Network);

-- Constants
local clickDebounce = 0.15;

local function sendStatsToClient(player: Player)
    local profile = playerData.GetData(player);
    player:SetAttribute('RawClicksData', http:JSONEncode(profile.Clicks));

    network:FireClient(player, 'LoadStatDisplay', profile);
end

function StatHandler.Click(player: Player)
    local profile = playerData.GetData(player);

    if not profile or profile.ClickDebounce then return end;

    profile.ClickDebounce = true;

    local increment = infMath.new(23156345);

    profile.Clicks = infMath.new(profile.Clicks + increment);
    player.leaderstats.Clicks.Value = infMath.new(profile.Clicks):GetSuffix(true);

    player:SetAttribute("RawClicksData", http:JSONEncode(profile.Clicks));

    task.delay(clickDebounce, function()
        profile.ClickDebounce = false;
    end)

    return increment
end

function StatHandler.ToggleAutoClicker(player: Player)
    local profile = playerData.GetData(player);
    if not profile or profile.ClickDebounce then return false end;

    profile.AutoClickerStatus = not profile.AutoClickerStatus;

    return profile.AutoClickerStatus;
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