local Shared = {}

Shared.DEFAULT_PLAYER_DATA = {
    Clicks = 0,
    Gems = 0,
    Rebirths = 1,
    Eggs = 0,

    LuckPercentage = 0,

    Pets = {},
    PetIndex = {},
    AutoDeletedPets = {},

    AutoClickerStatus = false,
    AutoRebirthStatus = false,
    AutoRebirthIndex = 0,

    ClickDebounce = false,
    HatchDebounce = false,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared