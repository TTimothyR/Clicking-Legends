local StatHandler = {}

-- Services
local players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")
local rs = game:GetService("ReplicatedStorage")
local physicsService = game:GetService("PhysicsService")
local runService = game:GetService("RunService")

-- Variables
local dataModules = sss:WaitForChild("DataModules")
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

local characterGroup = "CHAR"
local debrisGroup = "DEBRIS"

local rng = Random.new()

local playerDBs = {}

-- Modules
local playerData = require(dataModules.PlayerData)
local infMath = require(framework.InfiniteMath)
local network = require(framework.Network)
local globals = require(framework.Globals)
local petHandler = require(script.Parent.PetServerHandler)
local dataSync = require(dataModules.DataSyncServer)
local upgrades = require(library.Upgrades)

local function SetupCollision()
	pcall(function()
		physicsService:RegisterCollisionGroup(characterGroup)
	end)
	pcall(function()
		physicsService:RegisterCollisionGroup(debrisGroup)
	end)

	physicsService:CollisionGroupSetCollidable(characterGroup, debrisGroup, false)
	physicsService:CollisionGroupSetCollidable(debrisGroup, debrisGroup, false)
end

local function GetPetClicks(pets)
	local totalClicks = 0

	for _, petData in ipairs(pets) do
		if not petData.equipped then
			continue
		end
		totalClicks += globals.GetPetClicks(petData)
	end

	return totalClicks
end

local function IntializeDebounces(player: Player)
	local profile = playerData.GetData(player)
	local multiplier = (profile.UpgradeLevels["Faster Auto Click"] == 1) and upgrades["Faster Auto Click"].Increment
		or 1
	playerDBs[player.Name] = {
		ClickDB = 0.15,
		ClickOnDB = false,

		AutoClickerEnabled = profile.AutoClickerStatus,
		AutoClickDB = 0.25 / multiplier,
		AutoClickElapsedInterval = 0,
	}
end

local function HandleAutoClickers()
	runService.Heartbeat:Connect(function(deltaTime)
		for playerName, data in pairs(playerDBs) do
			task.spawn(function()
				if not data.AutoClickerEnabled then
					return
				end

				data.AutoClickElapsedInterval += deltaTime

				if data.AutoClickElapsedInterval < data.AutoClickDB then
					return
				end

				data.AutoClickElapsedInterval -= data.AutoClickDB

				task.spawn(StatHandler.Click, players:FindFirstChild(playerName), true)
			end)
		end
		task.wait()
	end)
end

function StatHandler.Click(player: Player, fromAutoClick: boolean)
	local profile = playerData.GetData(player)

	if not profile then
		return
	end
	if playerDBs[player.Name].ClickOnDB and not fromAutoClick then
		return
	end

	if not fromAutoClick then
		playerDBs[player.Name].ClickOnDB = true
		task.delay(playerDBs[player.Name].ClickDB, function()
			playerDBs[player.Name].ClickOnDB = false
		end)
	end

	task.spawn(function()
		for _, petData in ipairs(profile.Pets) do
			if petData.equipped and petData.level < 50 then
				petData.xp += 1
				local xpForNextLevel = globals.XPForNextLevel(petData.level, petData.shiny)

				if petData.xp >= xpForNextLevel then
					petHandler.LevelUp(player, petData.id)
				end
			end
		end
	end)

	local petIncrement = GetPetClicks(profile.Pets)
	local increment = infMath.new((100 + petIncrement) * profile.Rebirths)

	local criticalRoll = rng:NextInteger(1, 25)
	local critical = false
	if criticalRoll == 1 then
		increment *= 1.5
		critical = true
	end

	local upgradeLevels = profile.UpgradeLevels
	local criticalChance = upgradeLevels["x2 Click Chance"] * (upgrades["x2 Click Chance"].Increment / 100)

	if criticalChance > 0 then
		criticalChance = 100 / criticalChance

		local roll = rng:NextInteger(1, criticalChance)
		if roll == 1 then
			increment *= 2
		end
	end

	if fromAutoClick then
		network:FireClient(player, "PopUp", increment, "Clicks", critical)
	end

	local ownedGamepasses = profile.OwnedGamepasses
	if ownedGamepasses["Double Clicks"] then
		increment *= 2
	end

	profile.Clicks = infMath.new(profile.Clicks + increment)
	profile.TotalClicks = infMath.new(profile.TotalClicks + increment)
	player.leaderstats.Clicks.Value = infMath.new(profile.Clicks):GetSuffix(true)
	profile.ActualClicks = infMath.new(profile.ActualClicks + infMath.new(1))

	-- player:SetAttribute("Clicks", http:JSONEncode(profile.Clicks));
	-- player:SetAttribute("ActualClicks", http:JSONEncode(profile.ActualClicks));

	dataSync.SyncPlayer(player, profile)

	return true, increment, critical
end

function StatHandler.IncreaseAutoClickSpeed(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end
	if not playerDBs[player.Name] then
		return
	end
	local multiplier = (profile.UpgradeLevels["Faster Auto Click"] == 1) and upgrades["Faster Auto Click"].Increment
		or 1
	playerDBs[player.Name].AutoClickDB = 0.25 / multiplier
end

function StatHandler.ToggleAutoClicker(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return false
	end

	if profile.UpgradeLevels["Auto Clicker"] == 0 then
		return false
	end

	profile.AutoClickerStatus = not profile.AutoClickerStatus
	playerDBs[player.Name].AutoClickElapsedInterval = 0
	playerDBs[player.Name].AutoClickerEnabled = profile.AutoClickerStatus
	dataSync.SyncPlayer(player, profile)
end

function StatHandler.Initialize()
	if not game.Loaded then
		game.Loaded:Wait()
	end

	SetupCollision()
	HandleAutoClickers()

	for _, player: Player in ipairs(players:GetPlayers()) do
		task.spawn(IntializeDebounces, player)
	end

	players.PlayerAdded:Connect(function(player)
		task.spawn(IntializeDebounces, player)
	end)

	players.PlayerRemoving:Connect(function(player, reason)
		playerDBs[player.Name] = nil
	end)
end

return StatHandler
