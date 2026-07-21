local SettingsConfig = {
	["SFX"] = {
		Type = "Slider",
		DefaultValue = 1,
		MinimumValue = 0,
		MaximumValue = 1,
	},
	["Music"] = {
		Type = "Slider",
		DefaultValue = 0,
		MinimumValue = 0,
		MaximumValue = 1,
	},
	["LowDetail"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["Debug"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["ClickPopups"] = {
		Type = "Toggle",
		DefaultValue = true,
	},

	["HideAll"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["HideOthers"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["SkipEasyLegendaries"] = {
		Type = "Toggle",
		DefaultValue = false,
	},

	["HideEvents"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["HideItemPopups"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["EasyChances"] = {
		Type = "Toggle",
		DefaultValue = false,
	},
	["BotLink"] = {
		Type = "TextInput",
	},
}

return SettingsConfig
