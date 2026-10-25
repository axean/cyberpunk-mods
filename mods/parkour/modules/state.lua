-- The mod's shared state: written by the moves, read by the camera and by dev-log (through
-- GetMod("parkour").state).

---@class WallHit
---@field dist number
---@field normal number[]

---@class ParkourState
---@field enabled boolean wall moves on
---@field mode string "none", "wallrun" or "wallclimb"
---@field side integer wall run side: -1 left, 1 right, 0 none
---@field time number seconds in the current wall move
---@field last_exit string why the last wall move ended
---@field walls table<string, WallHit> hits by ray: left, right, left_high, right_high, ahead, ahead_high
---@field roll number camera roll in degrees, positive = right side down
---@field pitch number camera pitch in degrees, positive = up
---@field momentum boolean momentum on
---@field carry number m/s, V's speed cap as the mod sets it on the ground
---@field impact number m/s lost in the last impact
---@field input number[] stick: right, forward (-1..1)
---@field sprint_button boolean sprint (or toggle sprint) button down

---@type ParkourState
local state = {
    enabled = true,
    mode = "none",
    side = 0,
    time = 0,
    last_exit = "",
    walls = {},
    roll = 0,
    pitch = 0,
    momentum = true,
    carry = 0,
    impact = 0,
    input = { 0, 0 },
    sprint_button = false,
}

return state
