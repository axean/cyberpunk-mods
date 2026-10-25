-- Camera for the wall moves (from our Mirror's Edge captures): on a wall run the view rolls away
-- from the wall, on a wall climb it pitches up; the eye rises a little on both. Writes
-- state.roll and state.pitch.

local settings = require("modules/settings")
local state = require("modules/state")

local CAMERA = {
    roll_max = 22, -- degrees, tilted away from the wall on a wall run
    roll_in = 30, -- degrees per second while on the wall
    roll_out = 100, -- degrees per second back to level
    pitch_max = 25, -- degrees up on a wall climb (Mirror's Edge 50-80; more felt like only looking up)
    pitch_in = 200, -- degrees per second while climbing
    pitch_out = 150, -- degrees per second back
    run_lift = 0.1, -- m eye lift at full roll
    climb_lift = 0.12, -- m eye lift at full pitch
}

local camera = {}

---@param value number
---@param target number
---@param rate number
---@return number
local function approach(value, target, rate)
    if value < target then
        return math.min(target, value + rate)
    end
    return math.max(target, value - rate)
end

---@param player PlayerPuppet
---@param delta number
function camera.update(player, delta)
    local before_roll, before_pitch = state.roll, state.pitch
    local roll_target = -state.side * CAMERA.roll_max -- tilt away from the wall
    state.roll = approach(
        state.roll,
        roll_target,
        (state.side ~= 0 and CAMERA.roll_in or CAMERA.roll_out) * delta
    )
    local climbing = state.mode == "wallclimb"
    state.pitch = approach(
        state.pitch,
        climbing and CAMERA.pitch_max or 0,
        (climbing and CAMERA.pitch_in or CAMERA.pitch_out) * delta
    )
    if state.roll == 0 and before_roll == 0 and state.pitch == 0 and before_pitch == 0 then
        return
    end
    -- pitch about the camera's right (local X) axis, then roll about its forward (local Y) axis
    local a, c = math.sin(math.rad(state.pitch) / 2), math.cos(math.rad(state.pitch) / 2)
    local b, d = math.sin(math.rad(state.roll) / 2), math.cos(math.rad(state.roll) / 2)
    local fpp = player:GetFPPCameraComponent()
    fpp:SetLocalOrientation(Quaternion.new(d * a, c * b, a * b, c * d))
    local lift = math.max(
        CAMERA.run_lift * math.abs(state.roll) / CAMERA.roll_max,
        CAMERA.climb_lift * state.pitch / CAMERA.pitch_max
    )
    fpp:SetLocalPosition(Vector4.new(0, 0, lift, 0))
end

settings.section("camera", 5, CAMERA, {
    { key = "roll_max", label = "wall run roll (deg)", min = 0, max = 45, format = "%.0f" },
    { key = "roll_in", label = "roll in (deg/s)", min = 5, max = 150, format = "%.0f" },
    { key = "roll_out", label = "roll out (deg/s)", min = 20, max = 400, format = "%.0f" },
    { key = "pitch_max", label = "climb pitch (deg)", min = 0, max = 70, format = "%.0f" },
    { key = "pitch_in", label = "pitch in (deg/s)", min = 20, max = 500, format = "%.0f" },
    { key = "pitch_out", label = "pitch out (deg/s)", min = 20, max = 500, format = "%.0f" },
    { key = "run_lift", label = "wall run eye lift (m)", min = 0, max = 0.3 },
    { key = "climb_lift", label = "climb eye lift (m)", min = 0, max = 0.3 },
})

return camera
