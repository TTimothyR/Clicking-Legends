local RebirthHandler = {}

-- Services
local sss = game:GetService("ServerScriptService")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local dataModules = sss:WaitForChild("DataModules")
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local playerData = require(dataModules.PlayerData)
local rebirthStats = require(library.RebirthStats)
local infMath = require(framework.InfiniteMath)
local globals = require(framework.Globals)
local dataSync = require(dataModules.DataSyncServer).Private
local upgrades = require(library.Upgrades)

local function GetPetGems(pets)
	local totalGems = 0

	for _, petData in ipairs(pets) do
		if not petData.equipped then
			continue
		end
		totalGems += globals.GetPetGems(pets, petData)
	end
	return totalGems
end

function RebirthHandler.AttemptRebirth(player: Player, rebirthIndex: number)
	local profile = playerData.GetData(player)

	if not rebirthStats[rebirthIndex] then
		return
	end

	if not profile.OwnedRebirthButtons[rebirthIndex] then
		return
	end

	local rebirthAmount = rebirthStats[rebirthIndex]
	local clicks = infMath.new(profile.Clicks)
	local rebirths = infMath.new(profile.Rebirths)

	if rebirthIndex == 1 then
		if not profile.OwnedGamepasses["Max Rebirths"] then
			return
		end

		rebirthAmount = infMath.new(clicks / (globals.RebirthBasePrice * rebirths))
		rebirthAmount = infMath.floor(rebirthAmount)
	end
	if rebirthAmount == infMath.new(0) then
		return
	end

	local price = infMath.new(globals.RebirthBasePrice * rebirthAmount * rebirths)

	local petGems = GetPetGems(profile.Pets)
	local gemsPerRebirth = petGems < 1 and 10 or 10 * petGems

	if clicks >= price then
		local activePotions = profile.ActivePotions
		if activePotions["Rebirths"] then
			local tier, data = next(activePotions["Rebirths"].Active)

			if tier and data then
				rebirthAmount *= 1 + (globals.GetPotionBuffAmount(tier, "Rebirths") / 100)
			end
		end
		if profile.OwnedGamepasses["x2 Rebirths"] then
			rebirthAmount *= 2
		end
		if profile.OwnedGamepasses["x2 Gems"] then
			gemsPerRebirth *= 2
		end

		local upgradeLevels = profile.UpgradeLevels
		gemsPerRebirth *= 1 + upgradeLevels["More Gems"] * (upgrades["More Gems"].Increment / 100)

		profile.Clicks = infMath.new(0)
		-- player:SetAttribute('Clicks', http:JSONEncode(profile.Clicks));
		local leaderstats = player:FindFirstChild("leaderstats") :: Folder
		leaderstats.Clicks.Value = profile.Clicks:GetSuffix(true)

		profile.Gems = infMath.new(profile.Gems + (gemsPerRebirth * rebirthAmount))
		if infMath.new(profile.TotalGems) == infMath.new(0) then
			profile.TotalGems = infMath.new(gemsPerRebirth * rebirthAmount)
		else
			profile.TotalGems = infMath.new(profile.TotalGems + (gemsPerRebirth * rebirthAmount))
		end
		-- player:SetAttribute('Gems', http:JSONEncode(profile.Gems));
		leaderstats.Gems.Value = profile.Gems:GetSuffix(true)
		profile.Rebirths = infMath.new(profile.Rebirths + rebirthAmount)
		-- player:SetAttribute('Rebirths', http:JSONEncode(profile.Rebirths));
		leaderstats.Rebirths.Value = profile.Rebirths:GetSuffix(true)

		dataSync.SyncPlayer(player, profile)
		return true, infMath.new(rebirthAmount):GetSuffix(true)
	end
	return false, nil
end

function RebirthHandler.ToggleAutoRebirth(player: Player)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end

	if profile.UpgradeLevels["Auto Rebirth"] == 0 then
		return
	end

	profile.AutoRebirthStatus = not profile.AutoRebirthStatus
	dataSync.SyncPlayer(player, profile)
end

function RebirthHandler.SetAutoRebirthIndex(player: Player, rebirthIndex: number)
	local profile = playerData.GetData(player)
	if not profile then
		return
	end

	if profile.UpgradeLevels["Auto Rebirth"] == 0 then
		return
	end

	if rebirthIndex == 1 then
		return
	end

	if not profile.OwnedRebirthButtons[rebirthIndex] then
		return
	end

	if rebirthIndex == profile.AutoRebirthIndex then
		profile.AutoRebirthIndex = 0
	else
		profile.AutoRebirthIndex = rebirthIndex
	end

	dataSync.SyncPlayer(player, profile)
end

return RebirthHandler
