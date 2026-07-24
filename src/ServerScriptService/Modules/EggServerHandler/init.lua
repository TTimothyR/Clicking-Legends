local EggHandler = {}

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")

local Framework = ReplicatedStorage:WaitForChild("Framework")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")
local dataModules = sss:WaitForChild("DataModules")

-- Modules
local BotHandler = require(script.Parent.BotHandler).Private
local LegendaryChatHandler = require(script.LegendaryChatHandler)
local eggStats = require(library.EggStats)
local petStats = require(library.PetStats)
local playerData = require(dataModules.PlayerData)
local infMath = require(framework.InfiniteMath)
local generateID = require(framework.GenerateID)
local network = require(framework.Network)
local luckHandler = require(script.Parent.LuckHandler)
local TutorialServerHandler = require(script.Parent.TutorialServerHandler)
local dataSync = require(dataModules.DataSyncServer).Private
local Globals = require(ReplicatedStorage.Framework.Globals)
local ImageService = require(ReplicatedStorage.Framework.Library.ImageService)
local TutorialSteps = require(ReplicatedStorage.Framework.Library.TutorialSteps)
local Upgrades = require(ReplicatedStorage.Framework.Library.Upgrades)
local Network = require(Framework:WaitForChild("Network"))

local function ValidateDistance(player: Player, eggName: string)
	local maxDistance = 15

	local view = workspace.Eggs[eggName].View

	local character = player.Character
	local distance = (character.HumanoidRootPart.Position - view.Position).Magnitude
	return distance <= maxDistance
end

local function GetRawChanceFromPetName(eggName: string, petName: string, shiny: boolean)
	local tbl = eggStats[eggName].Pets
	if shiny then
		return tbl[petName][1] / 40
	end
	return tbl[petName][1]
end

local function CalculateHatchTime(player: Player, secret)
	if secret then
		return Globals.SecretHatchTime
	end
	local profile = playerData.GetData(player)

	local ownedGamepsses = profile.OwnedGamepasses
	local upgradeLevels = profile.UpgradeLevels
	local baseSpeed = 1
	local baseHatchTime = Globals.BaseHatchTime

	local activePotions = profile.ActivePotions
	if activePotions["Speed"] then
		local tier, data = next(activePotions["Speed"].Active)

		if tier and data then
			baseSpeed += Globals.GetPotionBuffAmount(tier, "Speed") / 100
		end
	end

	if ownedGamepsses["Fast Hatch"] then
		baseSpeed += 0.35
	end
	if next(upgradeLevels) ~= nil then
		baseSpeed += upgradeLevels["Faster Egg Open"] * (Upgrades["Faster Egg Open"].Increment / 100)
	end

	local totalHatchTime = baseHatchTime / baseSpeed

	return totalHatchTime
end

local function ResetVariables(player: Player, startUp: boolean)
	if startUp == nil then
		startUp = false
	end

	local profile = playerData.GetData(player)
	if not profile then
		warn("Could not fetch profile.")
		return
	end

	local uiLock = player:FindFirstChild("UILock") :: BoolValue
	uiLock.Value = false
	profile.HatchDebounce = false
	if startUp and profile.SavedPlayerPosition == nil then
		profile.IsAutoHatching = false
		profile.TargetAutoHatchEgg = ""
	end
	dataSync.SyncPlayer(player, profile)
end

function EggHandler.ToggleAutoHatch(player: Player, eggName: string, new: boolean)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end
	if not player:IsInGroupAsync(Globals.GroupID) then
		return false
	end
	profile.IsAutoHatching = new
	profile.TargetAutoHatchEgg = eggName

	if profile.IsAutoHatching then
		EggHandler.OpenEgg(player, eggName, profile.EggHatches)
	end

	dataSync.SyncPlayer(player, profile)

	return true
end

function EggHandler.UnlockEgg(plr: Player, eggName: string)
	if type(eggName) ~= "string" then
		return false
	end
	local profile = playerData.GetData(plr)
	if not profile then
		return false
	end

	if profile.UnlockedEggs[eggName] then
		return false
	end

	local clicks = infMath.new(profile.Clicks)
	local priceForOne = infMath.new(eggStats[eggName].Price[2])
	local price = infMath.new(priceForOne * 1)

	if clicks >= price then
		Network:FireClient(plr, "UnlockEggCutscene", eggName)
		task.delay(2.7, function()
			profile.UnlockedEggs[eggName] = true
			EggHandler.OpenEgg(plr, eggName, 1)
			dataSync.SyncPlayer(plr, profile)
		end)
		return true
	end

	return false
end

function EggHandler.OpenEgg(player: Player, eggName: string, amount: number)
	if not ValidateDistance(player, eggName) then
		EggHandler.ToggleAutoHatch(player, "", false)
		-- print("Too far away from egg.")
		-- network:FireClient(player, "UnableToOpen", "You are too far away from the egg.")
		return
	end
	if not eggStats[eggName] then
		EggHandler.ToggleAutoHatch(player, "", false)
		warn("Invalid egg name", eggName)
		network:FireClient(player, "UnableToOpen", "Invalid egg name, please report this to a developer.")
		return
	end

	local profile = playerData.GetData(player)
	local UnlockedEggs = profile.UnlockedEggs
	if not UnlockedEggs[eggName] then
		EggHandler.ToggleAutoHatch(player, "", false)
		-- warn("Player does not own egg", eggName)
		return
	end

	if not profile then
		EggHandler.ToggleAutoHatch(player, "", false)
		warn("Could not fetch profile for player", player.Name)
		network:FireClient(player, "UnableToOpen", "Failed to get profile, please report this to a developer.")
		return
	end

	if profile.HatchDebounce then
		print("Hatching on cooldown.")
		return
	end

	if #profile.Pets + amount > profile.PetStorage then
		EggHandler.ToggleAutoHatch(player, "", false)
		return
	end

	local world = eggStats[eggName].World
	if not profile.OwnedWorlds[world] then
		return
	end

	local clicks = infMath.new(profile.Clicks)
	local priceForOne = infMath.new(eggStats[eggName].Price[2])
	local price = infMath.new(priceForOne * amount)

	if clicks < price then
		local newAmount = math.floor(infMath.new(clicks / priceForOne):Reverse())
		if newAmount > 0 then
			amount = newAmount
			price = infMath.new(priceForOne * amount)
		else
			EggHandler.ToggleAutoHatch(player, "", false)
			warn("Not enough currency")
			network:FireClient(player, "UnableToOpen", "You do not have enough currency to afford this egg.")
			return
		end
	end

	profile.HatchDebounce = true

	profile.Clicks = infMath.new(profile.Clicks - price)

	local leaderstats = player:FindFirstChild("leaderstats")

	leaderstats.Clicks.Value = profile.Clicks:GetSuffix(true)

	profile.Eggs += amount
	leaderstats.Eggs.Value = profile.Eggs

	if not profile.TutorialFinished then
		local currentStep = profile.TutorialProgress.Step
		if currentStep == 2 then
			TutorialServerHandler.Advance(player, TutorialSteps[currentStep].ID, 1)
		end
	end

	-- player:SetAttribute('Clicks', http:JSONEncode(profile.Clicks));
	-- player:SetAttribute('Eggs', http:JSONEncode(profile.Eggs));

	local petData = {}
	local changes = {}

	local secret = false

	for _ = 1, amount do
		local petName, shiny = luckHandler.RollPet(player, eggName)
		local rawChance = GetRawChanceFromPetName(eggName, petName, shiny)
		local calculatedChance = 100 / rawChance
		if calculatedChance > profile.RarestHatch then
			profile.RarestHatch = calculatedChance
		end
		local rarity = petStats[petName].Rarity
		if petStats[petName].Secret then
			secret = true
			if shiny then
				profile.ShinySecretsHatched += 1
			else
				profile.SecretsHatched += 1
			end
			-- Discord.SecretPet(player, petName, (shiny == true and "Shiny" or nil), eggName)
		end
		local fullName = shiny and "Shiny " .. petName or petName
		local id = generateID.NewID()

		local autoDeleted = profile.AutoDeletedPets[petName]
		local new = false

		if not profile.PetIndex[fullName] then
			profile.PetIndex[fullName] = true
			new = true
			autoDeleted = false
		end

		table.insert(petData, {
			petName = petName,
			fullName = fullName,
			rarity = rarity,
			shiny = shiny,
			autoDeleted = autoDeleted,
			new = new,
		})

		if not autoDeleted then
			table.insert(profile.Pets, {
				petName = petName,
				fullName = fullName,
				shiny = shiny,
				id = id,
				level = 1,
				xp = 0,
				date = os.time(),
				locked = false,
				equipped = false,
				enchant = "",
			})

			if rarity == "Legendary" then
				local waitTime = secret and Globals.SecretHatchTime or Globals.BaseHatchTime
				task.delay(waitTime, function()
					LegendaryChatHandler.SendLegendaryMessage(player, petName, eggName, shiny)
				end)
			end

			if petStats[petName].Secret then
				local found = false
				for _, entry in ipairs(changes) do
					if entry.petName == petName and entry.isShiny == shiny then
						entry.delta += 1
						found = true
						break
					end
				end

				if not found then
					table.insert(changes, {
						petName = petName,
						isShiny = shiny,
						imageId = tostring(ImageService[fullName]:gsub("rbxassetid://", "")) or "",
						chance = tostring(infMath.new(calculatedChance):GetSuffix(true)),
						delta = 1,
					})
				end
			end

			if profile.AFKStartTime > 0 then
				if profile.PreAFKInfo["Pets"][fullName] == nil then
					profile.PreAFKInfo["Pets"][fullName] = 0
				end
				profile.PreAFKInfo["Pets"][fullName] += 1
			end
		end
	end

	if #changes > 0 then
		task.spawn(function()
			BotHandler.Hatch(player.Name, HttpService:JSONEncode(changes))
		end)
	end

	local uiLock = player:FindFirstChild("UILock") :: BoolValue
	uiLock.Value = true
	dataSync.SyncPlayer(player, profile)
	network:FireClient(player, "EggAnimation", eggName, amount, petData)
	task.delay(CalculateHatchTime(player, secret), function()
		ResetVariables(player, false)
	end)
end

function EggHandler.RequestNextHatch(player: Player)
	local profile = playerData.GetData(player)
	if not profile or not profile.IsAutoHatching then
		return
	end
	local uiLock = player:FindFirstChild("UILock") :: BoolValue
	if uiLock.Value then
		return
	end
	if profile.HatchDebounce then
		return
	end

	task.delay(0.3, function()
		EggHandler.OpenEgg(player, profile.TargetAutoHatchEgg, profile.EggHatches)
	end)
end

function EggHandler.Initialize()
	for _, player: Player in ipairs(players:GetPlayers()) do
		task.spawn(ResetVariables, player, true)
	end
	players.PlayerAdded:Connect(function(player)
		task.spawn(ResetVariables, player, true)
	end)
end

return EggHandler
