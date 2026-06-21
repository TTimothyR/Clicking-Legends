local Shared = {}

-- Services
local rs = game:GetService("ReplicatedStorage")

-- Variables
local framework = rs:WaitForChild("Framework")

-- Modules
local infMath = require(framework.InfiniteMath)

Shared.DEFAULT_PLAYER_DATA = {
	ActualClicks = infMath.new(0),
	Clicks = infMath.new(0),
	TotalClicks = infMath.new(0),
	Gems = infMath.new(0),
	TotalGems = infMath.new(0),
	Rebirths = infMath.new(1),
	Eggs = infMath.new(0),

	LuckPercentage = 0,
	EggHatches = 3,
	RarestHatch = 0,
	SecretsHatched = 0,
	ShinySecretsHatched = 0,

	ClickMultiplier = 0,

	PetEquips = 4,
	CurrentEquips = 0,
	PetStorage = 250,

	TotalRobuxSpent = 0,
	TimePlayed = 0,

	Pets = {},
	PetIndex = {},
	Items = {
		["Potions"] = {},
	},
	ActivePotions = {},
	AutoDeletedPets = {},
	ClaimedPrizes = {
		["Eggs"] = {},
		["ActualClicks"] = {},
	},
	UpgradeLevels = {},
	OwnedGamepasses = {},
	RedeemedCodes = {},

	IsInTrade = false,
	HasTradingDisabled = false,
	TradeRequestFrom = "",

	AutoClickerStatus = false,
	AutoRebirthStatus = false,
	AutoRebirthIndex = 0,

	IsAutoHatching = false,
	TargetAutoHatchEgg = "",

	HatchDebounce = false,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared
