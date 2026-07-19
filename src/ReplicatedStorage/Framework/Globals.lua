local Globals = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")
local library = framework:WaitForChild("Library")

-- Modules
local items = require(ReplicatedStorage.Framework.Library.Items)
local GlobalEventsModule = require(ReplicatedStorage.Framework.Library.GlobalEventsModule)
local eggStats = require(library.EggStats)
local petStats = require(library.PetStats)

Globals.LegendaryGradientRotateSpeed = 10 -- seconds per 360 degrees
Globals.SecretGradientRotateSpeed = 10 -- seconds per 360 degrees
Globals.RebirthBasePrice = 2250
Globals.UpgradeMultiplier = 1.35
-- Globals.CostCoefficient = 5
-- Globals.MultiplierCoefficient = 0.8
Globals.ExistRefreshTime = 10 * 60
Globals.BaseXP = 20
Globals.XPMulti = 2.1
Globals.MaxLevel = 50
Globals.ShinyMulti = 1.5
Globals.ShinyChance = 40
Globals.GroupID = 891290039
Globals.BaseHatchTime = 6
Globals.BestPotionTier = "V"
Globals.DailyResetTime = 24 * 3600
Globals.DailyClaimTreshold = 15 * 60

Globals.CharacterGroup = "CHAR"
Globals.DebrisGroup = "DEBRIS"
Globals.RarityColors = {
	["Common"] = Color3.fromRGB(255, 214, 133),
	["Uncommon"] = Color3.fromRGB(173, 255, 135),
	["Rare"] = Color3.fromRGB(255, 130, 130),
	["Epic"] = Color3.fromRGB(201, 126, 255),
	["Legendary"] = Color3.fromRGB(255, 255, 255),
}

Globals.RarityOrder = {
	["Legendary"] = 5,
	["Epic"] = 4,
	["Rare"] = 3,
	["Uncommon"] = 2,
	["Common"] = 1,
}

Globals.BuffColors = {
	["Lucky"] = Color3.fromRGB(35, 255, 64),
	["Rebirths"] = Color3.fromRGB(255, 44, 44),
	["Speed"] = Color3.fromRGB(255, 212, 148),
}

Globals.PotionDescriptions = {
	["Lucky"] = 'Grants <font color="%s">+%s%%</font> more luck!',
	["Rebirths"] = 'Grants <font color="%s">+%s%%</font> more rebirths!',
	["Speed"] = 'Increase hatch speed by <font color="%s">+%s%%</font>!',
}

Globals.ButtonPresets = {
	["Green"] = {
		StrokeColor = Color3.fromRGB(0, 131, 0),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0, 1, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(0.6666667, 1, 0)),
		}),
	},
	["Red"] = {
		StrokeColor = Color3.fromRGB(131, 0, 2),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0.4, 0.41)),
		}),
	},
	["Orange"] = {
		StrokeColor = Color3.fromRGB(131, 70, 0),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0.533333, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0.729411, 0.4)),
		}),
	},
	["Gray"] = {
		StrokeColor = Color3.fromRGB(96, 96, 96),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0.623529, 0.615686, 0.615686)),
			ColorSequenceKeypoint.new(1, Color3.new(0.650980, 0.650980, 0.650980)),
		}),
	},
	["Purple"] = {
		StrokeColor = Color3.fromRGB(91, 0, 136),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0.6666667, 0, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(0.6666667, 0.3333333, 1)),
		}),
	},
}

-- I dont know if this function should be here, but it will be used on the server for trading
-- And on the client to indicate which ones are duplicate so the player can delete them
function Globals.GetPetDuplicates(pets)
	local scannedIds = {}
	local dupes = {}

	for _, petData in ipairs(pets) do
		local id = petData.id

		if scannedIds[id] then
			if not dupes[id] then
				dupes[id] = true
			end
		else
			scannedIds[id] = true
		end
	end

	return dupes
end

function Globals.GetGiftDuplicates(gifts)
	local scannedIds = {}
	local dupes = {}

	for id, _ in ipairs(gifts) do
		if scannedIds[id] then
			if not dupes[id] then
				dupes[id] = true
			end
		else
			scannedIds[id] = true
		end
	end

	return dupes
end

function Globals.GetAnimatedGradients(
	parents: { [number]: Instance },
	gradientsToAnimate: { [number]: UIGradient }
): { [number]: UIGradient }
	local function AddGradient(child)
		if child.Glow.Legendary.Enabled then
			table.insert(gradientsToAnimate, child.Glow.Legendary)
		end
		if child.Frame.Legendary.Enabled then
			table.insert(gradientsToAnimate, child.Frame.Legendary)
		end
	end
	for _, parent in ipairs(parents) do
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("ImageButton") or child:IsA("Frame") then
				if not child:FindFirstChild("Glow") then
					local click = child:FindFirstChildOfClass("ImageButton")
					AddGradient(click)
				else
					AddGradient(child)
				end
			end
		end
	end

	return gradientsToAnimate
end

function Globals.SortPets(petA, petB)
	local petStatsA = petStats[petA.petName]
	local petStatsB = petStats[petB.petName]
	local rarityA = petStatsA.Rarity
	local rarityB = petStatsB.Rarity

	local rarityOrderA = Globals.RarityOrder[rarityA] or 0
	local rarityOrderB = Globals.RarityOrder[rarityB] or 0

	if rarityOrderA ~= rarityOrderB then
		return rarityOrderA > rarityOrderB
	end

	local petAClicks = petStatsA.Clicks
	local petBClicks = petStatsB.Clicks

	if petAClicks ~= petBClicks then
		return petAClicks > petBClicks
	end

	return petA.petName > petB.petName
end

function Globals.GetPotionBuffAmount(tier, buff)
	for _, data in pairs(items["Potions"][tier].Buffs) do
		if data[1] == buff then
			return data[2]
		end
	end

	return 0
end

function Globals.XPForNextLevel(currentLevel, shiny: boolean)
	if currentLevel < 50 then
		local xpNeeded
		if currentLevel == 1 then
			xpNeeded = Globals.BaseXP
		else
			xpNeeded = Globals.BaseXP * ((currentLevel - 1) * Globals.XPMulti)
		end
		if shiny then
			xpNeeded *= Globals.ShinyMulti
		end
		return xpNeeded
	end
	return 0
end

function Globals.GetPetClicks(petData)
	if not petData then
		return 0
	end
	if not petData.petName then
		return 0
	end
	local stats = petStats[petData.petName]
	if not stats.Clicks then
		return 0
	end

	local clicks = stats.Clicks
	local total = clicks * (1 + (2 * (petData.level - 1)) / (Globals.MaxLevel - 1))
	if petData.shiny then
		total *= 1.5
	end
	return total
end

function Globals.GetMaxLevelClicks(petData)
	if not petData then
		return 0
	end
	if not petData.petName then
		return 0
	end
	local stats = petStats[petData.petName]
	if not stats.Clicks then
		return 0
	end

	local clicks = stats.Clicks
	local total = clicks * (1 + (2 * (Globals.MaxLevel - 1)) / (Globals.MaxLevel - 1))
	if petData.shiny then
		total *= 1.5
	end
	return total
end

function Globals.GetMaxLevelGems(petData)
	if not petData then
		return 0
	end
	if not petData.petName then
		return 0
	end
	local stats = petStats[petData.petName]
	if not stats.Gems then
		return 0
	end

	local gems = stats.Gems
	local total = gems * (1 + (2 * (Globals.MaxLevel - 1)) / (Globals.MaxLevel - 1))
	if petData.shiny then
		total *= 1.5
	end
	return total
end

function Globals.GetPetGems(petData)
	if not petData then
		return 0
	end
	if not petData.petName then
		return 0
	end
	local stats = petStats[petData.petName]
	if not stats.Gems then
		return 0
	end

	local gems = stats.GemMulti
	local total = gems * (1 + (2 * (petData.level - 1)) / (Globals.MaxLevel - 1))
	if petData.shiny then
		total *= 1.5
	end
	return total
end

function Globals.GetRawPetChance(petName: string, eggName: string)
	for name, data in pairs(eggStats[eggName].Pets) do
		if name == petName then
			return data[1]
		end
	end

	return nil
end

function Globals.GetPetChance(gpOwned: boolean, luckPercentage, petName: string, eggName: string, shiny: boolean)
	local tbl = eggStats[eggName].Pets
	local boosted = { ["Epic"] = true, ["Legendary"] = true }

	local chances = {}
	local addedChance = 0
	local totalNonBoostedRaw = 0
	local totalWeight = 0
	if gpOwned then
		luckPercentage *= 2
	end

	if GlobalEventsModule.IsActive("LuckEvent") == true then
		luckPercentage *= GlobalEventsModule.GetMulti("LuckEvent")
	end

	local luckBoost = 1 + (luckPercentage / 100)

	for item, chance in pairs(tbl) do
		local rarity = petStats[item].Rarity
		if boosted[rarity] and luckBoost > 1 then
			local boostedChance = chance[1] * luckBoost
			addedChance += (boostedChance - chance[1])
			chances[item] = boostedChance
		else
			totalNonBoostedRaw += chance[1]
		end
	end

	local scaleFactor = 1
	if luckBoost > 1 and totalNonBoostedRaw > 0 then
		scaleFactor = math.max(0, (totalNonBoostedRaw - addedChance) / totalNonBoostedRaw)
	end

	for item, chance in pairs(tbl) do
		local rarity = petStats[item].Rarity
		if not (boosted[rarity] and luckBoost > 1) then
			chances[item] = chance[1] * scaleFactor
		end
		totalWeight += chances[item]
	end

	local finalChance = shiny and chances[petName] / Globals.ShinyChance or chances[petName]
	return finalChance
end

function Globals.FormatTime(seconds, letterRepresentation: boolean)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secondsLeft = math.floor(seconds % 60)
	if not letterRepresentation then
		if seconds <= 0 then
			return "00:00:00:00"
		end
		return string.format("%02d:%02d:%02d:%02d", days, hours, minutes, secondsLeft)
	else
		if seconds <= 0 then
			return "0s"
		end
		local formatted = ""
		if days > 0 then
			formatted ..= tostring(days) .. "d "
		end
		if hours > 0 then
			formatted ..= tostring(hours) .. "h "
		end
		if minutes > 0 then
			formatted ..= tostring(minutes) .. "m "
		end
		if secondsLeft > 0 then
			formatted ..= tostring(secondsLeft) .. "s"
		end
		return formatted
	end
end

function Globals.FormatNumber(number)
	local s = tostring(math.floor(number))
	local result = ""
	local count = 0

	for i = #s, 1, -1 do
		if count > 0 and count % 3 == 0 then
			result = "," .. result
		end
		result = s:sub(i, i) .. result
		count += 1
	end

	return result
end

function Globals.FormatChance(chance: number): string
	if chance == 0 then
		return "0"
	end

	if chance == math.floor(chance) then
		return tostring(chance)
	end

	local absChance = math.abs(chance)
	local exponent = math.floor(math.log10(absChance))
	local decimalPlaces = math.max(2, -exponent + 1)

	local formatStr = "%." .. tostring(decimalPlaces) .. "f"
	local formatted = string.format(formatStr, chance)

	formatted = string.gsub(formatted, "0+$", "")
	formatted = string.gsub(formatted, "%.$", "")

	return formatted
end

function Globals.GetCycle(secondsPerCycle)
	return math.floor(os.time() / secondsPerCycle)
end

function Globals.GetResetTime(secondsPerCycle)
	local now = os.time()
	local cycleStart = math.floor(now / secondsPerCycle) * secondsPerCycle
	local nextReset = cycleStart + secondsPerCycle
	return nextReset
end

return Globals
