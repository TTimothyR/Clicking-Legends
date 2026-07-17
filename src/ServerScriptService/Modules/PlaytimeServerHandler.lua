local PlaytimeHandler = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")
local runService = game:GetService("RunService")

-- Variables
local dataModules = sss:WaitForChild("DataModules")
local playerTimers = {}

local activeDayCycle = nil

-- Modules
local Globals = require(ReplicatedStorage.Framework.Globals)
local PlaytimeRewards = require(ReplicatedStorage.Framework.Library.PlaytimeRewards)
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
		return { Name = dailyRewards.GuaranteedRewards[day].Name, Amount = dailyRewards.GuaranteedRewards[day].Amount or 1 }
	else
		local category = PlaytimeRewards.GetRandomCategory() :: PlaytimeRewards.RewardCategory
		return PlaytimeRewards.GetRandomFromCategory[category]()
	end
end

local function LoadDailyRewards(player: Player)
	local profile = playerData.GetData(player)
	local savedCycle = profile.DailyCycle
	local currentCycle = Globals.GetDayCycle(Globals.DailyResetTime)
	local dailyStreak = profile.DailyStreak
	local dailyRewards = profile.DailyRewards

	if savedCycle ~= currentCycle then
		profile.DailyCycle = currentCycle
		local completed: boolean, day: string = CheckDayCompletion(dailyRewards)

		if not completed then
			dailyStreak = 0
			dailyRewards = {}
		else
			local nextDay = tonumber((day:gsub("Day", ""))) :: number + 1
			local nextDayString = ("Day" .. nextDay) :: string
			dailyStreak += 1
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
	-- Resetting the timer on client
end

function PlaytimeHandler.Initialize()
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
		local newDayCycle = Globals.GetDayCycle(Globals.DailyResetTime)

		if newDayCycle ~= activeDayCycle then
			for _, player: Player in ipairs(players:GetPlayers()) do
				AdvanceDay(player)
			end
		end
	end)
end

return PlaytimeHandler
