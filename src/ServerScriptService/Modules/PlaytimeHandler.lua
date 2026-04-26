local PlaytimeHandler = {};

-- Services
local players = game:GetService('Players');
local sss = game:GetService('ServerScriptService');
local runService = game:GetService('RunService');

-- Variables
local dataModules = sss:WaitForChild('DataModules');
local playerTimers = {};

-- Modules
local playerData = require(dataModules.PlayerData);
local dataSync = require(dataModules.DataSyncServer);

local function InstantiatePlayerTimer(player: Player)
    playerTimers[player.Name] = {
        TimeTrigger = 1,
        ElapsedTime = 0
    }
end

local function DestroyPlayerTimer(player: Player)
    playerTimers[player.Name] = nil;
end

local function UpdatePlayerTimers()
    runService.Heartbeat:Connect(function(deltaTime)
        for playerName, data in pairs(playerTimers) do
            data.ElapsedTime += deltaTime;
            if data.ElapsedTime >= data.TimeTrigger then
                data.ElapsedTime -= data.TimeTrigger;
                local profile = playerData.GetData(players:FindFirstChild(playerName));
                if profile then
                    profile.TimePlayed += data.TimeTrigger;
                    dataSync.SyncPlayer(players:FindFirstChild(playerName), profile);
                end
            end
        end
        task.wait();
    end)
end

function PlaytimeHandler.Initialize()
    for _, player: Player in ipairs(players:GetPlayers()) do
        InstantiatePlayerTimer(player);
    end
    players.PlayerAdded:Connect(function(player)
        InstantiatePlayerTimer(player);
    end)
    players.PlayerRemoving:Connect(function(player, reason)
        DestroyPlayerTimer(player);
    end)
    UpdatePlayerTimers();
end

return PlaytimeHandler