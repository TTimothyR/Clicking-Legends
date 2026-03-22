local Globals = {};

-- Services
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

-- Modules
local eggStats = require(library.EggStats);
local petStats = require(library.PetStats);

Globals.RebirthBasePrice = 2250
Globals.UpgradeMultiplier = 1.35;
-- Globals.CostCoefficient = 5
-- Globals.MultiplierCoefficient = 0.8
Globals.BaseXP = 20;
Globals.XPMulti = 2.1;
Globals.MaxLevel = 50;
Globals.ShinyMulti = 1.5;

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

Globals.ButtonPresets = {
	['Green'] = {
		StrokeColor = Color3.fromRGB(0,131,0),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0, 1, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(0.6666667, 1, 0))
		})
	},	
	['Red'] = {
		StrokeColor = Color3.fromRGB(131,0,2),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0.4, 0.41))
		})
	},		
	['Orange'] = {
		StrokeColor = Color3.fromRGB(131, 70, 0),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 0.533333, 0)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 0.729411, 0.4))
		})
	},		
	['Gray'] = {
		StrokeColor = Color3.fromRGB(96, 96, 96),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0.623529, 0.615686, 0.615686)),
			ColorSequenceKeypoint.new(1, Color3.new(0.650980, 0.650980, 0.650980))
		})
	},	
	['Purple'] = {
		StrokeColor = Color3.fromRGB(91,0,136),
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0.6666667, 0, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(0.6666667, 0.3333333, 1))
		})
	},
}

function Globals.XPForNextLevel(currentLevel, shiny: boolean)
	if currentLevel < 50 then
		local xpNeeded
		if currentLevel == 1 then
			xpNeeded = Globals.BaseXP;
		else
			xpNeeded = Globals.BaseXP * ((currentLevel - 1) * Globals.XPMulti);
		end
		if shiny then
			xpNeeded *= Globals.ShinyMulti;
		end
		return xpNeeded
	end
	return 0
end

function Globals.GetPetClicks(petData)
	local stats = petStats[petData.petName];
	
	local clicks = stats.Clicks;
	local total = clicks * (1+(2*(petData.level-1))/49);
	if petData.shiny then
		total *= 1.5;
	end
	return total;
end

function Globals.GetPetGems(petData)
	local stats = petStats[petData.petName];
	
	local gems = stats.GemMulti;
	local total = gems * (1+(2*(petData.level-1))/49);
	if petData.shiny then
		total *= 1.5;
	end
	return total;
end

function Globals.GetPetChance(gpOwned: boolean, luckPercentage, petName: string, eggName: string, shiny: boolean)
    local tbl = eggStats[eggName].Pets;
    local boosted = {['Epic'] = true, ['Legendary'] = true};

    local raw = {};
    local boostedChances = {};
    local chances = {};
    local addedChance = 0;
    local totalNonBoosted = 0;
    local totalWeight = 0;
	if gpOwned then
		luckPercentage *= 2;
	end

    local luckBoost = 1 + (luckPercentage/100);


	for item, chance in pairs(tbl) do
		raw[item] = chance[1]
		local rarity = petStats[item].Rarity
		if boosted[rarity] and luckBoost > 1 then
			boostedChances[item] = chance[1] * luckBoost
		else
			totalNonBoosted += 1
		end
	end

	if luckBoost > 1 then
		for item, _ in pairs(boostedChances) do
			addedChance += boostedChances[item] - raw[item]
		end
	end

	for item, chance in pairs(tbl) do
		local rarity = petStats[item].Rarity
		if boosted[rarity] then
			chances[item] = chance[1] * luckBoost
		else
			chances[item] = luckBoost ~= 1 and chance[1] - (addedChance / totalNonBoosted) or chance[1]
		end
		totalWeight += chances[item]
	end

    local chance = 0
    chance = shiny and chance/40 or chances[petName];
    return chance;
end

return Globals;