local PotionCraftingUtility = {
	PotionsRequired = {
		["II"] = 4,
		["III"] = 6,
		["IV"] = 8,
		["V"] = 10,
	},
}

function PotionCraftingUtility.GetRequirement(tier)
	local PotionsRequired = PotionCraftingUtility.PotionsRequired

	if not PotionsRequired[tier] then
		return
	end
	return PotionsRequired[tier]
end

function PotionCraftingUtility.GetNextTier(tier)
	local PotionTiers = { "I", "II", "III", "IV", "V" }
	local NextTierNumber = tier + 1
	local NextTierRoman = PotionTiers[NextTierNumber]
	if not NextTierRoman then
		return
	end
	return NextTierNumber, NextTierRoman
end

return PotionCraftingUtility
