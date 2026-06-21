local StatsUIHandler = {};

-- Services
local players = game:GetService("Players");
local rs = game:GetService('ReplicatedStorage');

-- Variables
repeat task.wait() until players.LocalPlayer;
local plr: Player = players.LocalPlayer;

local framework = rs:WaitForChild('Framework');

-- UI
local playerGui = plr:WaitForChild('PlayerGui');
local frames: ScreenGui = playerGui:WaitForChild('Frames');
local statsFrame = frames:WaitForChild('Stats');
local main = statsFrame:WaitForChild('Main');
local list = main:WaitForChild('List');
local scrollingHolder = list:WaitForChild('ScrollingFrame');

-- Modules
local dataSync = require(script.Parent.DataSyncClient);
local infMath = require(framework.InfiniteMath);
local globals = require(framework.Globals);

local function ChangeStat(newValue, prefixText, path)
    path.Text = prefixText..newValue;
end

local function InitializeStats()
    local profile = dataSync.GetAll();
    if not profile then return end;
    
    ChangeStat(infMath.new(profile.TotalClicks):GetSuffix(true), 'Total Clicks: ', scrollingHolder.TotalClicks.Title);
    ChangeStat(infMath.new(profile.TotalGems):GetSuffix(true), 'Total Gems: ', scrollingHolder.TotalGems.Title);
    ChangeStat(infMath.new(profile.Rebirths):GetSuffix(true), 'Total Rebirths: ', scrollingHolder.TotalRebirths.Title);

    ChangeStat(globals.FormatNumber(profile.RarestHatch), 'Rarest Hatch: 1/', scrollingHolder.RarestHatch.Title);
    ChangeStat(profile.SecretsHatched, 'Secrets Hatched: ', scrollingHolder.SecretsHatched.Title);
    ChangeStat(profile.ShinySecretsHatched, 'Shiny Secrets Hatched: ', scrollingHolder.ShinySecretsHatched.Title);
    ChangeStat(infMath.new(profile.Eggs):GetSuffix(true), 'Eggs: ', scrollingHolder.EggsHatched.Title);

    ChangeStat(globals.FormatTime(profile.TimePlayed), 'Time Played: ', scrollingHolder.TimePlayed.Title);
    ChangeStat(globals.FormatNumber(profile.TotalRobuxSpent), 'Robux Spent: ', scrollingHolder.RobuxSpent.Title);

    -- scrollingHolder.TotalClicks.Title.Text = "Total Clicks: "..profile.TotalClicks:GetSuffix(true);
    -- scrollingHolder.TotalGems.Title.Text = "Total Gems: "..profile.TotalGems:GetSuffix(true);
    -- scrollingHolder.TotalRebirths.Title.Text = "Total Rebirths: "..profile.Rebirths:GetSuffix(true);
    
    -- scrollingHolder.RarestHatch.Title.Text = "Rarest Hatch: 1/"..globals.FormatNumber(profile.RarestHatch);
    -- scrollingHolder.SecretsHatched.Title.Text = "Secrets Hatched: "..profile.SecretsHatched;
    -- scrollingHolder.ShinySecretsHatched.Title.Text = "Shiny Secrets Hatched: "..profile.ShinySecretsHatched;
    -- scrollingHolder.Eggs.Title.Text = "Eggs: "..profile.Eggs:GetSuffix(true);

    -- scrollingHolder.TimePlayed.Title.Text = "Time Played: "..globals.FormatTime(profile.TimePlayed);
    -- scrollingHolder.RobuxSpent.Title.Text = "Robux Spent: "..globals.FormatNumber(profile.TotalRobuxSpent);
end

function StatsUIHandler.Initialize()
    if not game.Loaded then game.Loaded:Wait() end;

    dataSync.OnReady(function()
        InitializeStats();
    end)

    dataSync.OnChanged('TotalClicks', function(newValue, oldValue)
        ChangeStat(infMath.new(newValue):GetSuffix(true), 'Total Clicks: ', scrollingHolder.TotalClicks.Title);
    end)

    dataSync.OnChanged('TotalGems', function(newValue, oldValue)
        ChangeStat(infMath.new(newValue):GetSuffix(true), 'Total Gems: ', scrollingHolder.TotalGems.Title);
    end)

    dataSync.OnChanged('Rebirths', function(newValue, oldValue)
        ChangeStat(infMath.new(newValue):GetSuffix(true), 'Total Rebirths: ', scrollingHolder.TotalRebirths.Title);
    end)

    dataSync.OnChanged('RarestHatch', function(newValue, oldValue)
        ChangeStat(globals.FormatNumber(newValue), 'Rarest Hatch: 1/', scrollingHolder.RarestHatch.Title);
    end)

    dataSync.OnChanged('SecretsHatched', function(newValue, oldValue)
        ChangeStat(newValue, 'Secrets Hatched: ', scrollingHolder.SecretsHatched.Title);
    end)

    dataSync.OnChanged('ShinySecretsHatched', function(newValue, oldValue)
        ChangeStat(newValue, 'Shiny Secrets Hatched: ', scrollingHolder.ShinySecretsHatched.Title);
    end)

    dataSync.OnChanged('Eggs', function(newValue, oldValue)
        ChangeStat(infMath.new(newValue):GetSuffix(true), 'Eggs: ', scrollingHolder.EggsHatched.Title);
    end)

    dataSync.OnChanged('TimePlayed', function(newValue, oldValue)
        ChangeStat(globals.FormatTime(newValue), 'Time Played: ', scrollingHolder.TimePlayed.Title);
    end)

    dataSync.OnChanged('TotalRobuxSpent', function(newValue, oldValue)
        ChangeStat(globals.FormatNumber(newValue), 'Robux Spent: ', scrollingHolder.RobuxSpent.Title);        
    end)
end

return StatsUIHandler;