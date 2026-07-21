local Enchants = require(script.Parent.Enchants)
return {
	Gamepasses = {
		["Max Rebirths"] = {
			Description = "Unlocks the option to Rebirth depending on your amount of Clicks!",
			GamepassID = 1895286808,
			GiftingID = 3610786979,
			LayoutOrder = 21,
		},
		["x2 Luck"] = { --
			Description = "Increases your luck on Legendary & Secret Pets!",
			GamepassID = 1893936487,
			GiftingID = 3609876126,
			LayoutOrder = 22,
		},
		["+500 Pet Storage"] = { --
			Description = "Store 500 more pets inside your inventory!",
			GamepassID = 1905769036,
			GiftingID = 3609876228,
			LayoutOrder = 23,
		},
		["Extra Egg"] = { --
			Description = "Hatch an extra egg while hatching eggs!",
			GamepassID = 1895934782,
			GiftingID = 3609876284,
			LayoutOrder = 24,
		},
		["Extra Equips"] = { --
			Description = "Equip 3 extra pets on your team!",
			GamepassID = 1896066782,
			GiftingID = 3609876428,
			LayoutOrder = 25,
		},
		["VIP"] = {
			Description = "+20% Clicks, +100 Storage and a VIP title!",
			GamepassID = 1907353609,
			GiftingID = 3609876489,
			LayoutOrder = 26,
		},
		["x2 Rebirths"] = { --
			Description = "Doubles the amount of Rebirths you obtain when grinding!",
			GamepassID = 1906057025,
			GiftingID = 3609876560,
			LayoutOrder = 27,
		},
		["Fast Hatch"] = { --
			Description = "Eggs hatch 50% faster!",
			GamepassID = 1895728790,
			GiftingID = 3609876622,
			LayoutOrder = 28,
		},
		["x2 Clicks"] = { --
			Description = "Doubles your Clicks gain while tapping!",
			GamepassID = 1895268732,
			GiftingID = 3609876722,
			LayoutOrder = 29,
		},
		["x2 Gems"] = { --
			Description = "Double the gems you earn when rebirthing!",
			GamepassID = 1896680791,
			GiftingID = 3609876789,
			LayoutOrder = 30,
		},
	},
	DeveloperProducts = {
		["Pet1"] = {
			ProductID = 3609877314,
			PetName = "King Star",
			Enchant = Enchants["Teamwork_👑"].Name,
		},
		["Pet2"] = {
			ProductID = 3609877424,
			PetName = "Doggy",
			Enchant = Enchants["Lucky_👑"].Name,
		},
		["PetCombi"] = {
			ProductID = 3609877566,
		},
		["RestockItemShop"] = {
			ProductID = 3608435738,
		},

		["GemPack1"] = {
			BaseGems = 10000,
			ProductID = 3609877024,
			LayoutOrder = 51,
		},
		["GemPack2"] = {
			BaseGems = 500,
			ProductID = 3609877103,
			LayoutOrder = 52,
		},
		["GemPack3"] = {
			BaseGems = 1000,
			ProductID = 3609877172,
			LayoutOrder = 53,
		},
		["GemPack4"] = {
			BaseGems = 2500,
			ProductID = 3609877228,
			LayoutOrder = 54,
		},
	},
}
