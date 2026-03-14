local Shared = {}

-- Services
local rs = game:GetService('ReplicatedStorage');

-- Variables
local framework = rs:WaitForChild('Framework');

-- Modules
local infMath = require(framework.InfiniteMath);

Shared.DEFAULT_PLAYER_DATA = {
    ActualClicks = infMath.new(0),
    Clicks = infMath.new(0),
    Gems = infMath.new(0),
    Rebirths = infMath.new(1),
    Eggs = infMath.new(0),

    LuckPercentage = 50,
    EggHatches = 3,

    ClickMultiplier = 0,

    PetEquips = 4,
    CurrentEquips = 0,
    PetStorage = 250,

    TotalRobuxSpent = 0,

    Pets = {},
    PetIndex = {},
    AutoDeletedPets = {},
    ClaimedPrizes = {
        ['Eggs'] = {},
        ['ActualClicks'] = {}
    },
    OwnedGamepasses = {},
    RedeemedCodes = {},

    IsInTrade = false,
    HasTradingDisabled = false,
    TradeRequestFrom = '',

    AutoClickerStatus = false,
    AutoRebirthStatus = false,
    AutoRebirthIndex = 0,

    IsAutoHatching = false,
    TargetAutoHatchEgg = '',

    ClickDebounce = false,
    HatchDebounce = false,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared