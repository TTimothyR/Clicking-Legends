local PlaytimeHandler = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")
local runService = game:GetService("RunService")

-- Variables
local dataModules = sss:WaitForChild("DataModules")
local playerTimers = {}

local activeDayCycle = nil

-- Modules
local RewardHandler = require(ServerScriptService.Modules.Private.RewardHandler)
local Globals = require(ReplicatedStorage.Framework.Globals)
local PlaytimeRewards = require(ReplicatedStorage.Framework.Library.PlaytimeRewards)
local Network = require(ReplicatedStorage.Framework.Network)
local playerData = require(dataModules.PlayerData)
local dataSync = require(dataModules.DataSyncServer).Private

local function InstantiatePlayerTimer(player: Player)
	playerTimers[player.Name] = {
		TimeTrigger = 1,
		ElapsedTime = 0,
	}
end

local function DestroyPlayerTimer(player: Player)
	playerTimers[player.Name] = nil
end

local function UpdatePlayerTimers()
	runService.Heartbeat:Connect(function(deltaTime)
		for playerName, data in pairs(playerTimers) do
			data.ElapsedTime += deltaTime
			if data.ElapsedTime >= data.TimeTrigger then
				data.ElapsedTime -= data.TimeTrigger
				local profile = playerData.GetData(players:FindFirstChild(playerName))
				if profile then
					profile.TimePlayed += data.TimeTrigger
					dataSync.SyncPlayer(players:FindFirstChild(playerName), profile)
				end
			end
		end
		task.wait()
	end)
end

local function CheckDayCompletion(dailyRewards): (boolean, any)
	for day: string, data in pairs(dailyRewards) do
		if data.Claimed then
			return true, day
		end
	end

	return false, nil
end

local function RollDailyReward(day: number): PlaytimeRewards.Reward
	local dailyRewards = PlaytimeRewards.DailyRewards
	if dailyRewards.GuaranteedRewards[day] then
		return {
			Name = dailyRewards.GuaranteedRewards[day].Name,
			Category = dailyRewards.GuaranteedRewards[day].Category,
			Amount = dailyRewards.GuaranteedRewards[day].Amount or 1,
		}
	else
		local category = PlaytimeRewards.GetRandomCategory() :: PlaytimeRewards.RewardCategory
		return PlaytimeRewards.GetRandomFromCategory[category]()
	end
end

local function LoadDailyRewards(player: Player)
	local profile = playerData.GetData(player)
	local savedCycle = profile.DailyCycle
	local currentCycle = Globals.GetCycle(Globals.DailyResetTime)
	local dailyRewards = profile.DailyRewards

	if savedCycle ~= currentCycle then
		profile.DailyCycle = currentCycle
		local completed: boolean, day: string = CheckDayCompletion(dailyRewards)

		if not completed then
			profile.DailyStreak = 0
			table.clear(dailyRewards)
		else
			local nextDay = tonumber((day:gsub("Day", ""))) :: number + 1
			local nextDayString = ("Day" .. nextDay) :: string
			dailyRewards[day] = nil
			dailyRewards[nextDayString].Active = true
			dailyRewards[nextDayString].EndTime = os.time() + Globals.DailyClaimTreshold
			dailyRewards[nextDayString].Remaining = Globals.DailyClaimTreshold
		end
	end

	if not next(dailyRewards) then
		for i = 1, 6, 1 do
			dailyRewards["Day" .. i] =
				{ EndTime = nil, Remaining = nil, Reward = RollDailyReward(i), Claimed = false, Active = false }
			if i == 1 then
				dailyRewards["Day" .. i].Active = true
				dailyRewards["Day" .. i].EndTime = os.time() + Globals.DailyClaimTreshold
				dailyRewards["Day" .. i].Remaining = Globals.DailyClaimTreshold
			end
		end
	end

	for day: string, data in pairs(dailyRewards) do
		if data.Active then
			local remaining = data.Remaining
			dailyRewards[day].EndTime = os.time() + remaining
			break
		end
	end

	dataSync.SyncPlayer(player, profile)
end

local function AdvanceDay(player: Player)
	LoadDailyRewards(player)
	Network:FireClient(player, "UpdateDayResetTimer")
end

function PlaytimeHandler.ClaimDailyReward(player: Player, day: number): boolean
	local profile = playerData.GetData(player)
	local dailyRewards = profile.DailyRewards

	local targetDay = dailyRewards["Day" .. day]
	local now = os.time()

	if not targetDay then
		return false
	end
	if targetDay.Claimed then
		return false
	end
	if not targetDay.Active then
		return false
	end
	if now < targetDay.EndTime then
		return false
	end

	local reward = targetDay.Reward :: PlaytimeRewards.Reward

	if reward.Category == "Potions" then
		RewardHandler.ClaimPotion(player, reward.Name, reward.Amount)
	elseif reward.Category == "Pets" then
		RewardHandler.ClaimPet(player, reward.Name, false, "")
	end

	targetDay.Claimed = true
	local newDay: number = day + 6
	dailyRewards["Day" .. newDay] = {
		EndTime = 0,
		Remaining = 0,
		Reward = RollDailyReward(newDay),
		Claimed = false,
		Active = false,
	}
	profile.DailyStreak += 1

	dataSync.SyncPlayer(player, profile)

	return true
end

function PlaytimeHandler.Initialize()
	activeDayCycle = Globals.GetCycle(Globals.DailyResetTime)
	for _, player: Player in ipairs(players:GetPlayers()) do
		task.spawn(LoadDailyRewards, player)
		task.spawn(InstantiatePlayerTimer, player)
	end
	players.PlayerAdded:Connect(function(player)
		task.spawn(LoadDailyRewards, player)
		task.spawn(InstantiatePlayerTimer, player)
	end)
	players.PlayerRemoving:Connect(function(player, _)
		DestroyPlayerTimer(player)
	end)
	UpdatePlayerTimers()

	runService.Heartbeat:Connect(function(_: number)
		local newDayCycle = Globals.GetCycle(Globals.DailyResetTime)

		if newDayCycle ~= activeDayCycle then
			activeDayCycle = newDayCycle
			for _, player: Player in ipairs(players:GetPlayers()) do
				AdvanceDay(player)
			end
		end
	end)
end

return PlaytimeHandler
