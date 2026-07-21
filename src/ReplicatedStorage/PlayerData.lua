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
	Eggs = 0,

	LuckPercentage = 0,
	EggHatches = 3,
	RarestHatch = 0,
	SecretsHatched = 0,
	ShinySecretsHatched = 0,

	ClickMultiplier = 0,
	HatchSpeed = 0,

	PetEquips = 4,
	CurrentEquips = 0,
	PetStorage = 250,

	TotalRobuxSpent = 0,
	Playtime = 0,

	IsFreeToPlay = true,

	OwnedRebirthButtons = {
		[1] = true,
		[2] = true,
	} :: { [number]: boolean },
	OwnedWorlds = {
		["Spawn"] = true,
	} :: { [string]: boolean },
	CurrentWorld = "Spawn",

	LastBotVerifyAttempt = 0,

	Settings = {},
	DailyRewards = {},
	DailyCycle = 0,
	DailyStreak = 0,

	Gifts = {},
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
	ClaimedEggs = {},
	UpgradeLevels = {},
	OwnedGamepasses = {},
	RedeemedCodes = {},
	UnlockedEggs = {},
	ItemShops = {},
	DailyShopRerolls = 3,
	NextDailyReroll = os.time(),
	CurrentItemShop = nil,

	IsInTrade = false,
	HasTradingDisabled = false,
	TradeRequestFrom = "",
	TradeBanned = false,

	AutoClickerStatus = false,
	AutoRebirthStatus = false,
	AutoRebirthIndex = 0,

	IsAutoHatching = false,
	TargetAutoHatchEgg = "",

	AFKStartTime = 0,
	SavedPlayerPosition = nil,
	PreAFKInfo = {},

	HatchDebounce = false,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared
