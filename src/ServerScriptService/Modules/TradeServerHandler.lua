local TradeHandler = {}

-- Services
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local runService = game:GetService("RunService")

-- Variables
local framework = rs:WaitForChild("Framework")
local dataModules = sss:WaitForChild("DataModules")

local trades = {}
local pendingRequests = {}

-- Modules
local network = require(framework.Network)
local generateID = require(framework.GenerateID)
local playerData = require(dataModules.PlayerData)
local tblUtil = require(framework.TableUtility)
local petHandler = require(script.Parent.PetServerHandler)
local dataSync = require(dataModules.DataSyncServer)

-- Constants
local startTime = 7
local lockInTrigger = 3

local function FindTradeID(player: Player)
	for id, trade in pairs(trades) do
		if trade.Players[player.Name] then
			return id
		end
	end
	return nil
end

local function IsOtherPlayerReady(readiedPlayer: Player, tradeID)
	for name, data in pairs(trades[tradeID].Players) do
		if name ~= readiedPlayer.Name then
			if data.Ready then
				return true, name
			end
		end
	end
	return false, nil
end

local function GetPlayerNames(trade)
	local names = {}

	for playerName, _ in pairs(trade.Players) do
		if players:FindFirstChild(playerName) then
			table.insert(names, playerName)
		end
	end
	return names
end

local function RemovePet(pets, id: string)
	for i, data in ipairs(pets) do
		if data.id == id then
			table.remove(pets, i)
			break
		end
	end
end

local function CompleteTrade(tradeID: string)
	local trade = trades[tradeID]
	if not trade then
		return
	end

	local playerNames = GetPlayerNames(trade)

	local player1: Player = players:FindFirstChild(playerNames[1])
	local player2: Player = players:FindFirstChild(playerNames[2])

	if not player1 or not player2 then
		if player1 then
			TradeHandler.DeclineTrade(player1)
		end
		return
	end
	local profile1 = playerData.GetData(player1)
	local profile2 = playerData.GetData(player2)

	local pets1 = profile1.Pets
	local pets2 = profile2.Pets

	local petsTo2 = trade.Players[playerNames[1]].Pets
	local petsTo1 = trade.Players[playerNames[2]].Pets

	for id, petData in pairs(petsTo2) do
		local clone = table.clone(petData)
		petHandler.UnequipPet(player1, id)
		clone.equipped = false
		table.insert(pets2, clone)
		RemovePet(pets1, id)
	end
	for id, petData in pairs(petsTo1) do
		local clone = table.clone(petData)
		petHandler.UnequipPet(player2, id)
		clone.equipped = false
		table.insert(pets1, clone)
		RemovePet(pets2, id)
	end

	trades[tradeID] = nil

	profile1.IsInTrade = false
	profile2.IsInTrade = false

	dataSync.SyncPlayer(player1, profile1)
	dataSync.SyncPlayer(player2, profile2)

	for _, playerName in ipairs(playerNames) do
		local plr: Player = players:FindFirstChild(playerName)
		network:FireClient(plr, "TradeFinished")
	end
	for _, player: Player in ipairs(players:GetPlayers()) do
		network:FireClient(player, "UpdateTradeButtons")
	end
end

local function StopTimer(tradeID: string)
	local trade = trades[tradeID]

	for playerName, _ in pairs(trade.Players) do
		local plr: Player = players:FindFirstChild(playerName)
		if not plr then
			continue
		end
		network:FireClient(plr, "StopTimer")
	end
	if trade.Settings.TimerConnection then
		trade.Settings.TimerConnection:Disconnect()
		trade.Settings.TimerConnection = nil
	end
	trade.Settings.TimerActive = false
	trade.Settings.Timer = startTime
end

local function StartTimer(tradeID: string)
	local trade = trades[tradeID]

	for playerName, _ in pairs(trade.Players) do
		local plr: Player = players:FindFirstChild(playerName)
		network:FireClient(plr, "StartTimer", startTime)
	end
	trade.Settings.TimerActive = true

	if trade.Settings.TimerConnection then
		trade.Settings.TimerConnection:Disconnect()
	end

	trade.Settings.TimerConnection = runService.Heartbeat:Connect(function(deltaTime)
		trade.Settings.Timer -= deltaTime

		if trade.Settings.Timer <= lockInTrigger and not trade.Settings.TradeLocked then
			trade.Settings.TradeLocked = true

			for playerName, _ in pairs(trade.Players) do
				local plr: Player = players:FindFirstChild(playerName)
				network:FireClient(plr, "LockTrade")
			end
		end

		if trade.Settings.Timer <= 0 then
			trade.Settings.TimerConnection:Disconnect()
			trade.Settings.TimerConnection = nil
			StopTimer(tradeID)
			CompleteTrade(tradeID)
		end
	end)
end

function TradeHandler.RequestAnswer(you: Player, me: Player, choice: boolean)
	local profile1 = playerData.GetData(you)
	local profile2 = playerData.GetData(me)
	if not choice then
		if pendingRequests[you.Name] and pendingRequests[you.Name].fromPlayerName == me.Name then
			pendingRequests[you.Name] = nil
			profile1.TradeRequestFrom = ""
			network:FireClient(me, "UpdateTradeButtons")
			dataSync.SyncPlayer(you, profile1)
		end
	end

	if pendingRequests[you.Name] then
		if pendingRequests[you.Name].fromPlayerName == me.Name then
			pendingRequests[you.Name] = nil
			profile1.TradeRequestFrom = ""

			profile1.IsInTrade = true
			profile2.IsInTrade = true

			network:FireClient(me, "EnterTrade", me, you)
			network:FireClient(you, "EnterTrade", you, me)

			local id: string = generateID.NewID()

			trades[id] = {
				Players = {
					[me.Name] = {
						Pets = {},
						Ready = false,
					},
					[you.Name] = {
						Pets = {},
						Ready = false,
					},
				},
				Settings = {
					Timer = startTime,
					TimerActive = false,
					TradeLocked = false,
					TimerConnection = nil,
				},
			}

			for _, plr: Player in ipairs(players:GetPlayers()) do
				network:FireClient(plr, "UpdateTradeButtons", me, you)
			end

			dataSync.SyncPlayer(you, profile1)
			dataSync.SyncPlayer(me, profile2)
		end
	end
end

function TradeHandler.SendTradeRequest(me: Player, you: Player)
	if FindTradeID(me) then
		return
	end
	if FindTradeID(you) then
		return
	end
	local profile = playerData.GetData(you)

	if profile.IsInTrade or profile.HasTradingDisabled then
		return
	end

	if pendingRequests[you.Name] then
		profile.TradeRequestFrom = ""

		local fromPlayerInstance = players:FindFirstChild(pendingRequests[you.Name].fromPlayerName) :: Player?

		if fromPlayerInstance then
			network:FireClient(fromPlayerInstance, "UpdateTradeButtons")
		end
	end

	profile.TradeRequestFrom = me.Name
	pendingRequests[you.Name] = { fromPlayerName = me.Name, timestamp = os.time() }
	dataSync.SyncPlayer(you, profile)

	network:FireClient(me, "UpdateTradeButtons")

	network:FireClient(you, "TradeRequest", me)
end

function TradeHandler.TogglePet(me: Player, id: string)
	local tradeID = FindTradeID(me)
	if not tradeID then
		return
	end
	local trade = trades[tradeID]

	if trade.Settings.TradeLocked then
		return
	end

	local profile = playerData.GetData(me)
	local pets = profile.Pets

	local index, petData = tblUtil.FindIndexWithId(pets, id)
	if not index then
		return
	end

	local state = nil
	if not trade.Players[me.Name].Pets[id] then
		trade.Players[me.Name].Pets[id] = petData
		state = "Added"
	else
		trade.Players[me.Name].Pets[id] = nil
		state = "Removed"
	end

	for playerName, _ in pairs(trade.Players) do
		local plr: Player = players:FindFirstChild(playerName)
		network:FireClient(plr, "TogglePet", me, petData, state)
		TradeHandler.Unready(plr)
	end
end

function TradeHandler.DeclineTrade(me: Player)
	local tradeID = FindTradeID(me)
	if not tradeID then
		return
	end
	local trade = trades[tradeID]

	if trade.TradeLocked then
		return
	end

	if trade.Settings.TimerActive then
		StopTimer(tradeID)
	end

	for playerName, _ in pairs(trade.Players) do
		local plr: Player = players:FindFirstChild(playerName)
		if not plr then
			continue
		end
		local profile = playerData.GetData(plr)
		if profile then
			profile.IsInTrade = false
			dataSync.SyncPlayer(plr, profile)
		end
		network:FireClient(plr, "DeclineTrade", me)
	end

	for _, player: Player in ipairs(players:GetPlayers()) do
		network:FireClient(player, "UpdateTradeButtons")
	end

	trades[tradeID] = nil
end

function TradeHandler.Ready(me: Player)
	local tradeID = FindTradeID(me)
	if not tradeID then
		return
	end
	local trade = trades[tradeID]

	if trade.Players[me.Name].Ready == true then
		return
	end

	trade.Players[me.Name].Ready = true

	local bool, _ = IsOtherPlayerReady(me, tradeID)

	if bool then
		StartTimer(tradeID)
	end

	for playerName, _ in pairs(trade.Players) do
		local plr: Player = players:FindFirstChild(playerName)
		network:FireClient(plr, "Ready", me)
	end
end

function TradeHandler.Unready(me: Player)
	local tradeID = FindTradeID(me)
	if not tradeID then
		return
	end
	local trade = trades[tradeID]

	if trade.Settings.TradeLocked then
		return
	end

	if trade.Players[me.Name].Ready == false then
		return
	end

	trade.Players[me.Name].Ready = false

	if trade.Settings.TimerActive then
		StopTimer(tradeID)
		local bool, otherName = IsOtherPlayerReady(me, tradeID)
		if bool then
			TradeHandler.Unready(players:FindFirstChild(otherName))
		end
	end

	for playerName, _ in pairs(trade.Players) do
		local plr: Player = players:FindFirstChild(playerName)
		if not plr then
			continue
		end
		network:FireClient(plr, "Unready", me)
	end
end

local function ResetVariables(player: Player)
	local profile = playerData.GetData(player)
	profile.IsInTrade = false
	profile.TradeRequestFrom = ""
	dataSync.SyncPlayer(player, profile)
end

function TradeHandler.Initialize()
	for _, player: Player in ipairs(players:GetPlayers()) do
		ResetVariables(player)
	end
	players.PlayerAdded:Connect(function(player)
		ResetVariables(player)
	end)
	players.PlayerRemoving:Connect(function(player, _)
		TradeHandler.DeclineTrade(player)
	end)

	task.spawn(function()
		while true do
			local time = os.time()
			for receivingPlayer, data in pairs(pendingRequests) do
				print(time - data.timestamp)
				if time - data.timestamp >= 10 then
					print("a trade should be disappearing")
					local receivingPlayerInstance = players:FindFirstChild(receivingPlayer) :: Player?
					local fromPlayerInstance = players:FindFirstChild(data.fromPlayerName) :: Player?

					print(receivingPlayerInstance, fromPlayerInstance)

					pendingRequests[receivingPlayer] = nil

					if receivingPlayerInstance then
						local profile = playerData.GetData(players:FindFirstChild(receivingPlayer))
						if profile then
							profile.TradeRequestFrom = ""
							dataSync.SyncPlayer(players:FindFirstChild(receivingPlayer), profile)
						end
						network:FireClient(receivingPlayerInstance, "HideTradeRequest")
						print("it did some stuff")
					end
					if fromPlayerInstance then
						network:FireClient(fromPlayerInstance, "UpdateTradeButtons")
						print("it did some more stuff")
					end
				end
			end
			task.wait(1)
		end
	end)
end

return TradeHandler
