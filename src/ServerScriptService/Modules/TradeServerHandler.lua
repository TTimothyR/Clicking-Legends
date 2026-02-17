local TradeHandler = {};

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local sss = game:GetService('ServerScriptService');
local runService = game:GetService('RunService');

-- Variables
local framework = rs:WaitForChild('Framework');
local dataModules: Folder = sss:WaitForChild('DataModules');

local trades = {};

-- Modules
local network = require(framework.Network);
local playerData = require(dataModules.PlayerData);
local tblUtil = require(framework.TableUtility);

-- Constants
local startTime = 7;
local lockInTrigger = 3;

local function FindTradeIndex(player: Player)
    for index, trade in ipairs(trades) do
        if trade[player.Name] then
            return index;
        end
    end
    return nil;
end

local function IsOtherPlayerReady(readiedPlayer: Player, tradeIndex)
    for name, data in pairs(trades[tradeIndex]) do
        if name ~= readiedPlayer.Name then
            if data.Ready then
                return true, name;
            end
        end
    end
    return false, nil;
end

local function GetPlayerNames(trade)
    local names = {};

    for playerName, _ in pairs(trade) do
        if players:FindFirstChild(playerName) then
            table.insert(names, playerName);
        end
    end
    return names;
end

local function RemovePet(pets, id: string)
    for i, data in ipairs(pets) do
        if data.id == id then
            pets[i] = nil;
        end
    end
end

local function CompleteTrade(tradeIndex: number)
    local trade = trades[tradeIndex];

    local playerNames = GetPlayerNames(trade);

    local profile1 = playerData.GetData(players:FindFirstChild(playerNames[1]));
    local profile2 = playerData.GetData(players:FindFirstChild(playerNames[2]));

    local pets1 = profile1.Pets;
    local pets2 = profile2.Pets

    local petsTo2 = trade[playerNames[1]].Pets;
    local petsTo1 = trade[playerNames[2]].Pets;

    for id, petData in pairs(petsTo2) do
        petData.equipped = false;
        table.insert(pets2, petData);
        RemovePet(pets1, id);
    end
    for id, petData in pairs(petsTo1) do
        petData.equipped = false;
        table.insert(pets1, petData);
        RemovePet(pets2, id);
    end

    table.remove(trades, tradeIndex);


    for _, playerName in ipairs(playerNames) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'TradeFinished');
    end
end

local function StartTimer(tradeIndex: number)
    local trade = trades[tradeIndex];

    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'StartTimer', startTime)
    end
    trade.TimerActive = true;

    local timerCon: RBXScriptConnection
    timerCon = runService.Heartbeat:Connect(function(deltaTime)
        trade.Timer -= deltaTime;
        
        if trade.Timer <= lockInTrigger and not trade.TradeLocked then
            trade.TradeLocked = true;
           
            for playerName, _ in pairs(trade) do
                local plr: Player = players:FindFirstChild(playerName);
                network:FireClient(plr, 'LockTrade');
            end
        end
        
        if trade.Timer <= 0 then
            timerCon:Disconnect();
            CompleteTrade();
        end
    end)
end

local function StopTimer(tradeIndex: number)
    local trade = trades[tradeIndex];

    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'StopTimer');
    end
    trade.TimerActive = false;
    trade.Timer = startTime;
end

function TradeHandler.SendTradeRequest(me: Player, you: Player)
    local accepted: boolean = network:InvokeClient(you, 'TradeRequest', me);

    if accepted then
        network:FireClient(me, 'EnterTrade', me, you);
        network:FireClient(you, 'EnterTrade', you, me);

        table.insert(trades,{
            [me.Name] = {
                Pets = {},
                Ready = false,
            },
            [you.Name] = {
                Pets = {},
                Ready = false,
            },
            Timer = startTime,
            TimerActive = false,
            TradeLocked = false
        })
        
        
        for _, plr: Player in ipairs(players:GetPlayers()) do
            network:FireClient(plr, 'UpdateTradeButtons', me, you);
        end
    end

    return accepted;
end

function TradeHandler.TogglePet(me: Player, id: string)
    local tradeIndex = FindTradeIndex(me);
    if not tradeIndex then return end;
    local trade = trades[tradeIndex];

    if trade.TradeLocked then return end;

    local profile = playerData.GetData(me);
    local pets = profile.Pets
    
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return end;

    local state = nil
    if not trade[me.Name].Pets[id] then
        trade[me.Name].Pets[id] = petData;
        state = 'Added';
    else
        trade[me.Name].Pets[id] = nil;
        state = 'Removed';
    end

    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'TogglePet', me, petData, state);
    end
end

function TradeHandler.DeclineTrade(me: Player)
    local tradeIndex = FindTradeIndex(me);
    if not tradeIndex then return end;
    local trade = trades[tradeIndex];

    if trade.TradeLocked then return end;

    if trade.TimerActive then
        StopTimer(tradeIndex);
    end

    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'DeclineTrade', me);
    end

    table.remove(trades, tradeIndex);
end

function TradeHandler.Ready(me: Player)
    local tradeIndex = FindTradeIndex(me);
    if not tradeIndex then return end;
    local trade = trades[tradeIndex];

    if trade[me.Name].Ready == true then return end;

    trade[me.Name].Ready = true;

    local bool, _ = IsOtherPlayerReady(me, tradeIndex);

    if bool then
        StartTimer(tradeIndex);
    end

    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'Ready', me);
    end
end

function TradeHandler.Unready(me: Player)
    local tradeIndex = FindTradeIndex(me);
    if not tradeIndex then return end;
    local trade = trades[tradeIndex];

    if trade.TradeLocked then return end;

    if trade[me.Name].Ready == false then return end;

    
    trade[me.Name].Ready = false;
    
    if trade.TimerActive then
        StopTimer(tradeIndex);
        local bool, otherName = IsOtherPlayerReady(me, tradeIndex);
        if bool then
            TradeHandler.Unready(players:FindFirstChild(otherName))
        end
    end
    
    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'Unready', me);
    end
end

return TradeHandler;