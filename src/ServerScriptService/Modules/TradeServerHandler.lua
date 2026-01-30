local TradeHandler = {};

-- Services
local players = game:GetService('Players');
local rs = game:GetService('ReplicatedStorage');
local sss = game:GetService('ServerScriptService');

-- Variables
local framework = rs:WaitForChild('Framework');
local dataModules: Folder = sss:WaitForChild('DataModules');

local trades = {};

-- Modules
local network = require(framework.Network);
local playerData = require(dataModules.PlayerData);
local tblUtil = require(framework.TableUtility);

local function FindTradeIndex(player: Player)
    for index, trade in ipairs(trades) do
        if trade[player.Name] then
            return index;
        end
    end
    return nil;
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
                Confirmed = false
            },
            [you.Name] = {
                Pets = {},
                Ready = false,
                Confirmed = false
            }
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

    local profile = playerData.GetData(me);
    local pets = profile.Pets
    
    local index, petData = tblUtil.FindIndexWithId(pets, id);
    if not index then return end;

    local state = nil
    if not trade[me.Name].Pets[id] then
        trade[me.Name].Pets[id] = true;
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

    for playerName, _ in pairs(trade) do
        local plr: Player = players:FindFirstChild(playerName);
        network:FireClient(plr, 'DeclineTrade', me);
    end
end

return TradeHandler;