local Shared = {}

Shared.DEFAULT_PLAYER_DATA = {
    ActualClicks = 0,
    Clicks = 0,
    Gems = 0,
    Rebirths = 1,
    Eggs = 0,

    LuckPercentage = 0,

    Pets = {},
    PetIndex = {},
    AutoDeletedPets = {},
    ClaimedPrizes = {
        ['Eggs'] = {},
        ['ActualClicks'] = {}
    },

    AutoClickerStatus = false,
    AutoRebirthStatus = false,
    AutoRebirthIndex = 0,

    ClickDebounce = false,
    HatchDebounce = false,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared