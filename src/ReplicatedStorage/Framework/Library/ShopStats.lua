local Enchants = require(script.Parent.Enchants)
return {
	Gamepasses = {
		["Max Rebirths"] = {
			Description = "Unlocks the option to Rebirth depending on your amount of Clicks!",
			GamepassID = 1741190838,
			GiftingID = 3606316395,
			LayoutOrder = 21,
		},
		["x2 Luck"] = { --
			Description = "Increases your luck on Legendary & Secret Pets!",
			GamepassID = 1740941898,
			LayoutOrder = 22,
		},
		["+500 Pet Storage"] = { --
			Description = "Store 500 more pets inside your inventory!",
			GamepassID = 1740895905,
			LayoutOrder = 23,
		},
		["Extra Egg"] = { --
			Description = "Hatch an extra egg while hatching eggs!",
			GamepassID = 1741430255,
			LayoutOrder = 24,
		},
		["Extra Equips"] = { --
			Description = "Equip 3 extra pets on your team!",
			GamepassID = 1740732188,
			LayoutOrder = 25,
		},
		["VIP"] = {
			Description = "Perks TBD",
			GamepassID = 1741144850,
			LayoutOrder = 26,
		},
		["x2 Rebirths"] = { --
			Description = "Doubles the amount of Rebirths you obtain when grinding!",
			GamepassID = 1741009950,
			LayoutOrder = 27,
		},
		["Fast Hatch"] = { --
			Description = "Eggs hatch 50% faster!",
			GamepassID = 1740933958,
			LayoutOrder = 28,
		},
		["x2 Clicks"] = { --
			Description = "Doubles your Clicks gain while tapping!",
			GamepassID = 1740766089,
			LayoutOrder = 29,
		},
		["x2 Gems"] = { --
			Description = "Double the gems you earn when rebirthing!",
			GamepassID = 1740983821,
			LayoutOrder = 30,
		},
	},
	DeveloperProducts = {
		["Pet1"] = {
			ProductID = 3548669529,
			PetName = "King Star",
			Enchant = Enchants["Teamwork_👑"].Name,
		},
		["Pet2"] = {
			ProductID = 3548669613,
			PetName = "Doggy",
			Enchant = Enchants["Lucky_👑"].Name,
		},
		["PetCombi"] = {
			ProductID = 3548669728,
		},
		["RestockItemShop"] = {
			ProductID = 3608435738,
		},

		["GemPack1"] = {
			BaseGems = 10000,
			ProductID = 3548669836,
			LayoutOrder = 51,
		},
		["GemPack2"] = {
			BaseGems = 500,
			ProductID = 3548669836,
			LayoutOrder = 52,
		},
		["GemPack3"] = {
			BaseGems = 1000,
			ProductID = 3548669836,
			LayoutOrder = 53,
		},
		["GemPack4"] = {
			BaseGems = 2500,
			ProductID = 3548669836,
			LayoutOrder = 54,
		},
	},
}
