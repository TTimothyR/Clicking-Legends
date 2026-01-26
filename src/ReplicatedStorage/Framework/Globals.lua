local Globals = {};

-- Services
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

-- Modules
local eggStats = require(library.EggStats);
local petStats = require(library.PetStats);

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

function Globals.GetPetChance(luckPercentage, petName: string, eggName: string, shiny: boolean)
    local tbl = eggStats[eggName].Pets;
    local boosted = {['Epic'] = true, ['Legendary'] = true};

    local raw = {};
    local boostedChances = {};
    local chances = {};
    local addedChance = 0;
    local totalNonBoosted = 0;
    local totalWeight = 0;

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