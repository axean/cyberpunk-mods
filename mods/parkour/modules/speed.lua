-- Base speed: a multiplier on V's speed cap in every movement state (slider "speed"). A stat
-- modifier, not a push, so the game's dash and jump boosts stay intact.

local settings = require("modules/settings")

local SPEED = {
    factor = 1.0, -- V's speed cap multiplied by this in every state
}

local speed = {}

---@type gameStatModifierData?
local modifier = nil
local applied = 1.0 -- the factor the current modifier applies

---@param player PlayerPuppet
local function remove(player)
    if modifier then
        Game.GetStatsSystem():RemoveModifier(player:GetEntityID(), modifier)
        modifier, applied = nil, 1.0
    end
end

-- The factor V's speed cap is multiplied by now.
---@return number
function speed.factor()
    return applied
end

-- Apply the setting if it changed; call every frame.
---@param player PlayerPuppet
function speed.update(player)
    local factor = SPEED.factor
    if math.abs(factor - applied) < 1e-3 then
        return
    end
    remove(player)
    if math.abs(factor - 1) >= 1e-3 then
        modifier = RPGManager.CreateStatModifier(
            gamedataStatType.MaxSpeed,
            gameStatModifierType.Multiplier,
            factor
        )
        Game.GetStatsSystem():AddModifier(player:GetEntityID(), modifier)
        applied = factor
    end
end

-- Forget the modifier without removing it (V was re-created, e.g. a save was loaded).
function speed.reset()
    modifier, applied = nil, 1.0
end

-- Remove the modifier (on shutdown).
---@param player PlayerPuppet
function speed.clear(player)
    remove(player)
end

settings.section("speed", 1, SPEED, {
    { key = "factor", label = "base speed", min = 1.0, max = 1.5, format = "x%.2f" },
})

return speed
