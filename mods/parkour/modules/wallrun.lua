-- Wall run: jump next to a tall wall while moving along it and V runs along the wall: lifted on
-- entry, then lower gravity (rising 8.2, falling 5.0 m/s² in Mirror's Edge; here +10%), a
-- little speed loss, footsteps. Ends when V falls too fast, the wall ends, or she lands; V's
-- double jump on the wall becomes a jump away from it.

local settings = require("modules/settings")
local state = require("modules/state")
local walls = require("modules/walls")
local world = require("modules/world")

local RUN = {
    max_dist = 1.0, -- m from V to the wall to start or keep running
    min_speed = 2.0, -- m/s horizontal to start
    max_angle = 57, -- degrees between V's movement and the wall
    min_entry_vz = -5.0, -- m/s, falling faster than this: no wall run
    lift = 5.15, -- m/s upward on entry
    gravity_up = 9.0, -- m/s² while rising on the wall (Mirror's Edge 8.2; +10%, felt floaty)
    gravity_down = 5.5, -- m/s² while falling on the wall (Mirror's Edge 5.0; +10%)
    exit_vz = -5.0, -- m/s, falling faster than this ends the run
    friction = 0.05, -- share of the speed along the wall lost per second
    stick_speed = 0.5, -- m/s toward the wall while running
    stick_gain = 0.3, -- share of the error toward stick_speed corrected per frame
    max_time = 3.0, -- s, safety limit
    cooldown = 0.15, -- s before the next wall run
    wall_grace = 0.1, -- s the side ray may miss the wall before the run ends
    jump_detect = 3.0, -- m/s, a sudden upward change this big is V's double jump
    jump_away = 5.0, -- m/s away from the wall when jumping off
    jump_up = 3.0, -- m/s upward when jumping off
}

local SOUND = {
    enter = "lcm_wallrun_in",
    exit = "lcm_wallrun_out",
    step = "lcm_fs_sneakers_concrete_sprint", -- a harder step than running: V connects to the wall
    step_interval = 0.28, -- s between footsteps on the wall
}

local wallrun = {}

local cooldown = 0
local missing = 0 -- s the wall has been missing during the run
local step_timer = 0
---@type number[]? velocity along the wall (x, y) and upward speed in the previous frame
local last = nil

---@param player PlayerPuppet
---@param reason string
function wallrun.stop(player, reason)
    state.mode, state.side, state.last_exit = "none", 0, reason
    cooldown = RUN.cooldown
    world.sound(player, SOUND.exit)
end

-- Start a wall run if V is in a jump next to a usable wall. Needs walls.scan_sides this frame.
---@param player PlayerPuppet
---@param v Vector4
---@param delta number
---@return boolean started
function wallrun.try_start(player, v, delta)
    cooldown = math.max(0, cooldown - delta)
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    if
        cooldown > 0
        or speed < RUN.min_speed
        or v.z < RUN.min_entry_vz
        or world.locomotion(player) ~= world.JUMP
    then
        return false
    end
    for _, side in ipairs({ { name = "right", sign = 1 }, { name = "left", sign = -1 } }) do
        local hit, tall = walls.usable(side.name, RUN.max_dist)
        if hit and tall then
            local nx, ny = hit.normal[1], hit.normal[2]
            local vn = v.x * nx + v.y * ny -- away from the wall is positive
            local into = -vn / speed -- sine of the angle to the wall, positive = toward it
            if into >= -0.2 and into <= math.sin(math.rad(RUN.max_angle)) then
                state.mode, state.side, state.time = "wallrun", side.sign, 0
                missing, step_timer, last = 0, 0, nil
                -- lift, and drop the velocity component into or away from the wall
                world.impulse(player, -vn * nx, -vn * ny, RUN.lift - v.z)
                world.sound(player, SOUND.enter)
                return true
            end
        end
    end
    return false
end

---@param player PlayerPuppet
---@param v Vector4
---@param delta number
function wallrun.update(player, v, delta)
    state.time = state.time + delta
    local hit = walls.usable(state.side == 1 and "right" or "left", RUN.max_dist)
    missing = hit and 0 or missing + delta
    if missing > RUN.wall_grace then
        wallrun.stop(player, "wall ended")
        return
    elseif v.z < RUN.exit_vz then
        wallrun.stop(player, "fell off")
        return
    elseif state.time > 0.1 and v.z <= 0 and world.on_ground(player) then
        wallrun.stop(player, "landed")
        return
    elseif state.time > RUN.max_time then
        wallrun.stop(player, "time limit")
        return
    end
    if not hit then
        return -- keep the current motion through a short gap
    end
    local nx, ny = hit.normal[1], hit.normal[2]
    local vn = v.x * nx + v.y * ny -- away from the wall is positive
    local tx, ty = v.x - vn * nx, v.y - vn * ny -- along the wall
    if last and state.time > 0.08 and v.z - last[3] > RUN.jump_detect then
        -- V's double jump: turn it into a jump off the wall, keeping the speed along it
        world.impulse(
            player,
            last[1] + RUN.jump_away * nx - v.x,
            last[2] + RUN.jump_away * ny - v.y,
            RUN.jump_up - v.z
        )
        wallrun.stop(player, "jumped off")
        return
    end
    last = { tx, ty, v.z }
    local gravity = v.z > 0 and RUN.gravity_up or RUN.gravity_down
    local stick = RUN.stick_gain * (-RUN.stick_speed - vn)
    local friction = RUN.friction * delta
    world.impulse(
        player,
        stick * nx - friction * tx,
        stick * ny - friction * ty,
        (world.GRAVITY - gravity) * delta
    )
    step_timer = step_timer + delta
    if step_timer >= SOUND.step_interval then
        step_timer = step_timer - SOUND.step_interval
        world.sound(player, SOUND.step)
    end
end

settings.section("wall run", 3, RUN, {
    { key = "min_speed", label = "min speed (m/s)", min = 0, max = 6 },
    { key = "max_angle", label = "max angle to wall (deg)", min = 20, max = 80, format = "%.0f" },
    { key = "max_dist", label = "max wall distance (m)", min = 0.5, max = 1.5 },
    { key = "lift", label = "entry lift (m/s)", min = 0, max = 9 },
    { key = "gravity_up", label = "gravity rising (m/s2)", min = 2, max = 16 },
    { key = "gravity_down", label = "gravity falling (m/s2)", min = 1, max = 16 },
    { key = "exit_vz", label = "fall off below (m/s)", min = -12, max = -1 },
    { key = "friction", label = "speed loss per s", min = 0, max = 0.5 },
    { key = "max_time", label = "max time (s)", min = 0.5, max = 5 },
    { key = "jump_away", label = "jump-off away (m/s)", min = 0, max = 10 },
    { key = "jump_up", label = "jump-off up (m/s)", min = 0, max = 8 },
    { key = "cooldown", label = "cooldown (s)", min = 0, max = 1 },
    {
        key = "step_interval",
        label = "footstep interval (s)",
        min = 0.1,
        max = 0.6,
        values = SOUND,
    },
})

return wallrun
