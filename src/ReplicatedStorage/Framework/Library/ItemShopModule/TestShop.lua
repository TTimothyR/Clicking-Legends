return {
	Name = "Test Shop",
	Currency = "Gems",
	RestockTime = 60,
	ItemPool = {
		--[itemName] = {itemType, weight, price, amount}
		["Lucky_I"] = { "Potions", 50, 250, 5 },
		["Speed_II"] = { "Potions", 30, 1_000, 4 },
		["Rebirths_III"] = { "Potions", 15, 2_500, 3 },
		["Lucky_V"] = { "Potions", 15, 10_000, 3 },
	},
}
