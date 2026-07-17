local Items = require(script.Parent.Items)
local PlaytimeRewards = {}

export type PotionReward = { Chance: number, MinimumAmount: number, MaximumAmount: number }
export type Reward = { Name: string, Amount: number }
export type RewardCategory = "Potions" | "Pets" | "Items"

PlaytimeRewards.DailyRewards = {
	["RandomRewards"] = {
		["Potions"] = {
			["I"] = { Chance = 35, MinimumAmount = 5, MaximumAmount = 10 },
			["II"] = { Chance = 25, MinimumAmount = 4, MaximumAmount = 9 },
			["III"] = { Chance = 20, MinimumAmount = 3, MaximumAmount = 6 },
			["IV"] = { Chance = 12, MinimumAmount = 2, MaximumAmount = 5 },
			["V"] = { Chance = 8, MinimumAmount = 1, MaximumAmount = 3 },
		} :: { [RewardCategory]: PotionReward },
	},
	["GuaranteedRewards"] = {
		[7] = { Type = "Pet", Name = "Grand Patriotic Overlord" },
		[14] = { Type = "Potion", Name = "Lucky_V", Amount = 25 },
	},
}

function PlaytimeRewards.GetRandomCategory(): RewardCategory
	local categories = {}
	for category, _ in pairs(PlaytimeRewards.DailyRewards.RandomRewards) do
		table.insert(categories, category)
	end

	local index = math.random(1, #categories)

	return categories[index]
end

PlaytimeRewards.GetRandomFromCategory = {
	["Potions"] = function(): Reward
		local chances = {}
		local totalWeight = 0
		local potionRewards = PlaytimeRewards.DailyRewards.RandomRewards["Potions"] :: { [string]: PotionReward }
		for tier, data: PotionReward in pairs(potionRewards) do
			chances[tier] = data.Chance
			totalWeight += data.Chance
		end

		local roll = math.random() * totalWeight
		local currentWeight = 0

		for tier, chance in pairs(chances) do
			currentWeight += chance
			if roll <= currentWeight then
				local amount = math.random(potionRewards[tier].MinimumAmount, potionRewards[tier].MaximumAmount)
				local randomBuff = Items[tier].Buffs[math.random(1, #Items[tier].Buffs)][1] :: string

				return { Name = randomBuff .. "_" .. tier, Amount = amount }
			end
		end

		return { Name = nil, Amount = 0 }
	end,
} :: { [RewardCategory]: () -> Reward }

PlaytimeRewards.PlaytimeGifts = {}

return PlaytimeRewards
