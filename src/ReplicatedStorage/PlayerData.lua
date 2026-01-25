local Shared = {}

Shared.DEFAULT_PLAYER_DATA = {
    Clicks = 0,
    Gems = 0,
    Rebirths = 0,
    Eggs = 0,

    LuckPercentage = 0,

    Pets = {},
    PetIndex = {},

    AutoClickerStatus = false,

    ClickDebounce = false
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared