-- Springboard (Mirror's Edge TdMove_SpringBoard): run at a low obstacle, look up above it and
-- jump, and V steps off it high into the air instead of vaulting over it.
--
-- Every frame on the ground it checks whether a springboard would happen ("armed"): V moving at
-- least min_speed toward an obstacle 0.6-1.5 m tall, within a bit more than the game's vault
-- range, looking up above its top. While armed the game's vault and ledge climb are held back
-- (their ranges in TweakDB set to 0), so the jump press gives a normal jump, which becomes the
-- springboard: upward speed as if stepping off the obstacle's top at jump_z, a little
-- horizontal speed given up, and a short hang with no gravity at the top. Not armed: the
-- game's vault as usual.

local settings = require("modules/settings")
local state = require("modules/state")
local walls = require("modules/walls")
local world = require("modules/world")

local BOARD = {
    min_speed = 4.0, -- m/s horizontal, else no springboard
    range_factor = 1.2, -- times the game's vault range (0.4 m, up to 2.0 m at 8.5 m/s)
    min_height = 0.6, -- m, obstacle top above the feet (Mirror's Edge SpringBoardMinHeight 0.8)
    max_height = 1.5, -- m (SpringBoardMaxHeight 1.48)
    min_pitch = 10, -- degrees: V looks up at least this much ...
    pitch_margin = 5, -- ... and this much above the obstacle's top edge
    max_approach = 45, -- degrees between V's movement and her facing
    jump_z = 9.5, -- m/s upward stepping off the top (SpringBoardJumpZ, 950 uu/s)
    speed_loss = 1.0, -- m/s horizontal given up (SpringBoardJumpXYAdd, -100 uu/s) ...
    min_out_speed = 4.0, -- ... but not below this (SpringBoardJumpXYMin, 400 uu/s)
    hang_time = 0.3, -- s with no gravity at the top (Mirror's Edge has 0.4 s of no gravity)
    follow_time = 0.05, -- s, time constant for holding the launch against the jump's own frames
    hold_time = 0.15, -- s the launch is held
    press_window = 0.2, -- s a jump press waits for V to leave the ground
}

-- The game's vault reaches minDetectionRange + (detectionRange - minDetectionRange) * speed /
-- maxSpeedNormalizer (VaultDecisions.ObstacleLengthCheck).
local VAULT = { min = 0.4, max = 2.0, speed = 8.5 }

-- TweakDB values that hold back the game's vault and ledge climb while armed.
local HOLD_BACK = {
    "playerStateMachineLocomotion.vault.detectionRange",
    "playerStateMachineLocomotion.vault.minDetectionRange",
    "playerStateMachineLocomotion.climb.obstacleEnterAngleThreshold",
}

local springboard = {}

local held_back = false
---@type table<string, number>
local originals = {}
local pending = 0 -- s left for a jump press to turn into a springboard
local launch_vz = 0 -- m/s planned upward speed during the hold
local hanging = 0 -- s of hang left (-1: not yet at the top)

---@param hold boolean
local function hold_back(hold)
    if hold == held_back then
        return
    end
    held_back = hold
    for _, path in ipairs(HOLD_BACK) do
        if originals[path] == nil then
            local ok, value = pcall(TweakDB.GetFlat, TweakDB, path)
            originals[path] = ok and tonumber(value) or nil
            print(string.format("parkour: %s = %s", path, tostring(originals[path])))
        end
        if originals[path] then
            pcall(TweakDB.SetFlat, TweakDB, path, hold and 0 or originals[path])
        end
    end
end

---@param reason string
local function stop(reason)
    state.mode, state.last_exit = "none", reason
end

-- Would a jump now be a springboard?
---@param player PlayerPuppet
---@param v Vector4
---@return Obstacle?
local function check(player, v)
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    if speed < BOARD.min_speed or not world.on_ground(player) then
        return nil
    end
    local fx, fy = world.facing(player)
    local dx, dy = v.x / speed, v.y / speed
    if dx * fx + dy * fy < math.cos(math.rad(BOARD.max_approach)) then
        return nil
    end
    local vault = VAULT.min + (VAULT.max - VAULT.min) * math.min(1, speed / VAULT.speed)
    local obstacle = walls.obstacle(player, dx, dy, vault * BOARD.range_factor, BOARD.max_height)
    if not obstacle or obstacle.top < BOARD.min_height then
        return nil
    end
    -- looking up, and above the obstacle's top edge (from the eye, ~1.6 m above the feet)
    local edge = math.deg(math.atan2(obstacle.top - 1.6, math.max(0.1, obstacle.dist)))
    if world.view_pitch() < math.max(BOARD.min_pitch, edge + BOARD.pitch_margin) then
        return nil
    end
    return obstacle
end

---@param player PlayerPuppet
---@param v Vector4
---@param top number
local function launch(player, v, top)
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    local out = speed
    if speed > BOARD.min_out_speed then
        out = math.max(BOARD.min_out_speed, speed - BOARD.speed_loss)
    end
    local scale = speed > 0.1 and (out - speed) / speed or 0
    launch_vz = math.sqrt(BOARD.jump_z * BOARD.jump_z + 2 * world.GRAVITY * top)
    world.impulse(player, v.x * scale, v.y * scale, launch_vz - v.z)
    state.mode, state.side, state.time = "springboard", 0, 0
    hanging = -1
end

local last_top = 0 -- m, the armed obstacle's top above the feet

-- Arm, hold back the game's vault, and launch on a jump press; call every frame while no move
-- is running.
---@param player PlayerPuppet
---@param v Vector4
---@param delta number
function springboard.watch(player, v, delta)
    if pending > 0 then
        pending = pending - delta
        if not world.on_ground(player) then
            pending = 0
            launch(player, v, last_top)
            hold_back(false)
            state.armed = false
            return
        end
    end
    local obstacle = check(player, v)
    state.armed = obstacle ~= nil or pending > 0
    if obstacle then
        last_top = obstacle.top
    end
    hold_back(state.armed)
    if state.jump_pressed then
        state.jump_pressed = false
        if obstacle then
            pending = BOARD.press_window
        end
    end
end

---@param player PlayerPuppet
---@param v Vector4
---@param delta number
function springboard.update(player, v, delta)
    state.time = state.time + delta
    launch_vz = launch_vz - world.GRAVITY * delta
    local loco = world.locomotion(player)
    if loco ~= world.JUMP and loco ~= world.DEFAULT then
        stop("game took over")
        return
    elseif state.time > 0.1 and world.on_ground(player) then
        stop("landed")
        return
    end
    if state.time < BOARD.hold_time then
        -- hold the launch against the jump's own first frames
        world.impulse(player, 0, 0, (launch_vz - v.z) * (1 - math.exp(-delta / BOARD.follow_time)))
    elseif hanging < 0 and v.z <= 0 then
        hanging = BOARD.hang_time
    end
    if hanging > 0 then
        hanging = hanging - delta
        world.impulse(
            player,
            0,
            0,
            world.GRAVITY * delta - v.z * (1 - math.exp(-delta / BOARD.follow_time))
        )
        if hanging <= 0 then
            stop("done")
        end
    end
end

-- Give the game its vault back (on shutdown or when turned off).
function springboard.release()
    hold_back(false)
    state.armed, pending = false, 0
end

settings.section("springboard", 4.5, BOARD, {
    { key = "min_speed", label = "min speed (m/s)", min = 0, max = 8 },
    { key = "range_factor", label = "range x vault range", min = 0.8, max = 2 },
    { key = "min_height", label = "min obstacle height (m)", min = 0.2, max = 1.5 },
    { key = "max_height", label = "max obstacle height (m)", min = 0.8, max = 2.2 },
    { key = "min_pitch", label = "look up at least (deg)", min = -10, max = 45, format = "%.0f" },
    {
        key = "pitch_margin",
        label = "look above edge by (deg)",
        min = -10,
        max = 30,
        format = "%.0f",
    },
    {
        key = "max_approach",
        label = "max approach angle (deg)",
        min = 10,
        max = 90,
        format = "%.0f",
    },
    { key = "jump_z", label = "launch speed (m/s)", min = 4, max = 15 },
    { key = "speed_loss", label = "speed given up (m/s)", min = 0, max = 4 },
    { key = "min_out_speed", label = "min speed after (m/s)", min = 0, max = 8 },
    { key = "hang_time", label = "hang at the top (s)", min = 0, max = 1 },
    { key = "press_window", label = "jump press window (s)", min = 0.05, max = 0.5 },
})

return springboard
