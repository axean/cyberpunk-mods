-- Wall climb: jump at a tall wall head-on (facing within 33° of straight at it) with the stick
-- forward and V runs up it, pulled tight against the wall. How high comes from her run-up
-- speed, shaped like Faith's climbs: generous from a moderate run-up (1.8 m at 3.5 m/s),
-- growing with speed, nothing from a standstill; on the wall gravity is lower, so it's a run
-- up rather than a hop. Ends when she stops rising, at the top of the wall (with a small push over the edge),
-- when the wall ends, or when the game's own ledge climb takes over.

local state = require("modules/state")
local walls = require("modules/walls")
local world = require("modules/world")

local CLIMB = {
    max_dist = 1.2, -- m to the wall ahead (Mirror's Edge WallClimbingMaxDistance2D, 120 uu)
    max_angle = 33, -- degrees between V's facing and straight at the wall (WallClimbingVerticalStartAngle)
    min_input = 0.5, -- stick forward at least this much
    -- climb height from the run-up speed toward the wall (Mirror's Edge captures: 1.8-1.95 m at
    -- ~3 m/s, 2.2-2.4 m at ~6.5 m/s):
    min_run_up = 1.0, -- m/s, nothing below this ...
    base_run_up = 3.5, -- m/s, ... rising to base_height here ...
    base_height = 1.8, -- m
    extra_height = 0.25, -- m per m/s above base_run_up
    min_height = 0.3, -- m, less isn't worth a climb
    max_vz = 9.0, -- m/s up at most (4.5 m of climb)
    run_up_time = 0.3, -- s, the run-up speed is the highest of about this long before
    gravity = 9.0, -- m/s² on the wall (game 16): a run up, not a hop
    friction = 12, -- 1/s, sideways speed on the wall fades this fast (Mirror's Edge ~12)
    hold_dist = 0.45, -- m from V's centre to the wall while climbing (her radius is 0.4)
    pull_gain = 8, -- 1/s, how fast she's pulled in to hold_dist ...
    pull_max = 4, -- ... at most this fast, m/s
    pull_time = 0.05, -- s, time constant for reaching that speed (a full correction per frame
    -- overshoots: the push lands a frame late)
    wall_grace = 0.1, -- s the ray may miss the wall before the climb ends
    jump_detect = 3.0, -- m/s, a sudden upward change this big is V's double jump
    top_push = 2.0, -- m/s toward the wall at the top, over the edge
    top_lift = 2.5, -- m/s upward at least, at the top
    max_time = 2.0, -- s, safety limit
}

local SOUND = {
    step = "lcm_fs_sneakers_concrete_run",
    step_interval = 0.15, -- s between footsteps on the wall
}

local wallclimb = {}

local used = false -- one climb per jump: set on entry, cleared on the ground
local missing = 0 -- s the wall has been missing during the climb
local step_timer = 0
local last_vz = 0
local nx, ny = 0, 0 -- the wall's normal (horizontal, away from the wall)
local run_up = 0 -- m/s, V's recent horizontal speed (the highest, fading over run_up_time)

-- V's wanted velocity along the wall's normal (away is positive) to be pulled in to
-- CLIMB.hold_dist from dist.
---@param dist number
---@return number
local function pull(dist)
    return -math.min(CLIMB.pull_max, math.max(0, (dist - CLIMB.hold_dist) * CLIMB.pull_gain))
end

---@param reason string
local function stop(reason)
    state.mode, state.last_exit = "none", reason
end

-- Start a wall climb if V is jumping at a usable wall ahead. Scans the wall ahead itself.
---@param player PlayerPuppet
---@param v Vector4
---@param delta number
---@return boolean started
function wallclimb.try_start(player, v, delta)
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    run_up = math.max(speed, run_up * math.exp(-delta / CLIMB.run_up_time))
    if world.on_ground(player) then
        used = false
        return false
    end
    if
        used
        or v.z <= 0
        or state.input[2] < CLIMB.min_input
        or world.locomotion(player) ~= world.JUMP
    then
        return false
    end
    local fx, fy = world.facing(player)
    walls.scan_ahead(player, fx, fy)
    local hit, tall = walls.usable("ahead", CLIMB.max_dist)
    if not hit or not tall then
        return false
    end
    local hx, hy = hit.normal[1], hit.normal[2]
    local length = math.sqrt(hx * hx + hy * hy)
    hx, hy = hx / length, hy / length
    if -(fx * hx + fy * hy) < math.cos(math.rad(CLIMB.max_angle)) then
        return false
    end
    -- the run-up toward the wall turned into climb height, and the upward speed for it
    local into = run_up * -(fx * hx + fy * hy)
    local height = CLIMB.base_height
            * math.max(
                0,
                math.min(1, (into - CLIMB.min_run_up) / (CLIMB.base_run_up - CLIMB.min_run_up))
            )
        + CLIMB.extra_height * math.max(0, into - CLIMB.base_run_up)
    if height < CLIMB.min_height then
        return false
    end
    local vz = math.min(math.sqrt(2 * CLIMB.gravity * height), CLIMB.max_vz)
    used, missing, step_timer, last_vz = true, 0, 0, vz
    nx, ny = hx, hy
    state.mode, state.side, state.time = "wallclimb", 0, 0
    local vn = v.x * nx + v.y * ny -- away from the wall is positive
    local tx, ty = v.x - vn * nx, v.y - vn * ny -- sideways along the wall: dropped
    local p = pull(hit.dist) - vn
    world.impulse(player, p * nx - tx, p * ny - ty, vz - v.z)
    world.sound(player, SOUND.step)
    return true
end

---@param player PlayerPuppet
---@param v Vector4
---@param delta number
function wallclimb.update(player, v, delta)
    state.time = state.time + delta
    walls.scan_ahead(player, -nx, -ny)
    local hit = walls.usable("ahead", CLIMB.max_dist)
    missing = hit and 0 or missing + delta
    local loco = world.locomotion(player)
    local jumped = state.time > 0.1 and v.z - last_vz > CLIMB.jump_detect
    last_vz = v.z
    if loco ~= world.JUMP and loco ~= world.DEFAULT then
        stop("game took over") -- the game's ledge climb, a vault, ...
        return
    elseif jumped then
        stop("jumped") -- V's double jump: keep its boost
        return
    elseif state.time > 0.1 and world.on_ground(player) then
        stop("landed")
        return
    elseif v.z <= 0 then
        stop("rise ended")
        return
    elseif missing > CLIMB.wall_grace then
        stop("wall ended")
        return
    elseif state.time > CLIMB.max_time then
        stop("time limit")
        return
    end
    if not hit then
        return -- keep the current motion through a short gap
    end
    nx, ny = hit.normal[1], hit.normal[2]
    local length = math.sqrt(nx * nx + ny * ny)
    nx, ny = nx / length, ny / length
    local vn = v.x * nx + v.y * ny
    if state.walls.ahead_high == nil then
        -- the top is in reach: over the edge
        world.impulse(
            player,
            (-CLIMB.top_push - vn) * nx,
            (-CLIMB.top_push - vn) * ny,
            math.max(0, CLIMB.top_lift - v.z)
        )
        stop("top")
        return
    end
    local tx, ty = v.x - vn * nx, v.y - vn * ny -- sideways along the wall
    local friction = math.min(1, CLIMB.friction * delta)
    local p = (pull(hit.dist) - vn) * (1 - math.exp(-delta / CLIMB.pull_time))
    world.impulse(
        player,
        p * nx - friction * tx,
        p * ny - friction * ty,
        (world.GRAVITY - CLIMB.gravity) * delta
    )
    step_timer = step_timer + delta
    if step_timer >= SOUND.step_interval then
        step_timer = step_timer - SOUND.step_interval
        world.sound(player, SOUND.step)
    end
end

-- End the climb (hotkey off).
function wallclimb.stop()
    stop("turned off")
end

return wallclimb
