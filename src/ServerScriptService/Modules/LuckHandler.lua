local LuckHandler = {}

-- Services
local rs = game:GetService('ReplicatedStorage');
local sss = game:GetService('ServerScriptService');

-- Variables
local rng = Random.new();
local dataModules = sss:WaitForChild('DataModules');
local framework = rs:WaitForChild('Framework');
local library = framework:WaitForChild('Library');

-- Modules
local playerData = require(dataModules.PlayerData);
local eggStats = require(library.EggStats);
local petStats = require(library.PetStats);

local function RollShiny()
    local shinyChance = 40;

    local roll = rng:NextNumber(1, shinyChance);
    if roll == 1 then
        return true;
    else
        return false;
    end
end

function LuckHandler.RollPet(player: Player, eggName: string)
    local profile = playerData.GetData(player);
    local luckPercentage = profile.LuckPercentage;

    local gamepass = false;
    local upgrade = false;
    if gamepass then
        luckPercentage *= 2;
    end
    if upgrade then
        luckPercentage *= 1.25;
    end

    local tbl = eggStats[eggName].Pets;
    local boosted = {['Epic'] = true, ['Legendary'] = true};

    local rawChances = {};
    local boostedChances = {};
    local chances = {};
    local addedChance = 0;
    local totalNonBoosted = 0;
    local totalWeight = 0

    local luckBoost = 1 + (luckPercentage/100);

    for item, chance in pairs(tbl) do
		rawChances[item] = chance[1]
		local rarity = petStats[item].Rarity
		if boosted[rarity] and luckBoost > 1 then
			boostedChances[item] = chance[1] * luckBoost
		else
			totalNonBoosted += 1
		end
	end

	if luckBoost > 1 then
		for item, _ in pairs(boostedChances) do
			addedChance += boostedChances[item] - rawChances[item]
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

    local roll = math.random() * totalWeight
	local currentWeight = 0

	for item, chance in pairs(chances) do
		currentWeight += chance
		if roll <= currentWeight then
            local pet = item;
			local shiny = RollShiny()
			return pet, shiny
		end
	end
end

return LuckHandler