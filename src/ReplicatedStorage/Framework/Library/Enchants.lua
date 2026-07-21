local Enchants = {
	["Lucky_👑"] = {
		Name = "Lucky_👑",
		Rarity = "Exclusive",
		Buff = 67,
		ExpiresAfter = nil,
	},
	["Teamwork_👑"] = {
		Name = "Teamwork_👑",
		Rarity = "Exclusive",
		Buff = 10,
		ExpiresAfter = nil,
	},
}

-- Name color, name, tier color, tier, buff color, buff
Enchants.Description = {
	["Lucky"] = '<font color="%s">%s</font> <font color="%s">%s</font> - Increases your luck by <font color="%s">%s%%</font>!',
	["Teamwork"] = '<font color="%s">%s</font> <font color="%s">%s</font> - Every pet on your team\'s stats are buffed by <font color="%s">+%s%%</font>!',
}

Enchants.Colors = {
	["Lucky"] = Color3.fromRGB(35, 255, 64),
	["Teamwork"] = Color3.fromRGB(35, 196, 255),
}

return Enchants
