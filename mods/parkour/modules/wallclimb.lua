-- Wall climb: jump at a tall wall head-on (facing within 33° of straight at it) with the stick
-- forward and V runs up it, pulled tight against the wall. How high comes from her run-up
-- speed, shaped like Faith's climbs: generous from a moderate run-up (1.8 m at 3.5 m/s),
-- growing with speed, nothing from a standstill; on the wall gravity is lower, so it's a run
-- up rather than a hop. Her upward speed follows that plan every frame, so the jump's own first
-- frames or small knocks don't cut the climb short.
--
-- Bumps on the wall (sills, pipes, signs): the rays above her head see them, often only for a
-- frame, so they're remembered (height, how far they stick out) and V is held clear of every
-- bump her body is passing. Ends when the plan runs out of upward speed, at the top of the wall
-- (with a small push over the edge), at an overhang, when something blocks her, when the wall
-- ends, or when the game's own ledge climb takes over.

local settings = require("modules/settings")
local state = require("modules/state")
local walls = require("modules/walls")
local world = require("modules/world")

local CLIMB = {
    max_dist = 1.2, -- m to the wall ahead (Mirror's Edge WallClimbingMaxDistance2D, 120 uu)
    max_angle = 33, -- degrees between V's facing and straight at the wall (WallClimbingVerticalStartAngle)
    min_input = 0.5, -- stick forward at least this much
    min_idle = 0.3, -- s since the last wall move (no climb right after a wall-run jump-off)
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
    follow_time = 0.05, -- s, time constant for following the planned upward speed
    blocked_gap = 1.5, -- m/s slower than planned ...
    blocked_time = 0.1, -- ... for this long: something solid is in the way
    friction = 12, -- 1/s, sideways speed on the wall fades this fast (Mirror's Edge ~12)
    hold_dist = 0.45, -- m from V's centre to the wall face, plus any bump (her radius is 0.4)
    pull_gain = 8, -- 1/s, how fast she's pulled in or pushed out to that distance ...
    pull_max = 5, -- ... at most this fast, m/s
    pull_time = 0.05, -- s, time constant for reaching that speed (a full correction per frame
    -- overshoots: the push lands a frame late)
    bump_min = 0.05, -- m a surface must stick out from the wall face to count as a bump
    body_height = 1.9, -- m, V's body above her feet ...
    look_ahead = 0.6, -- ... plus this much above it: bumps in this span keep her out
    max_offset = 0.8, -- m a bump may stick out from the wall; more is an overhang
    wall_grace = 0.1, -- s the rays may all miss the wall before the climb ends
    jump_detect = 3.0, -- m/s, a sudden upward change this big is V's double jump
    top_push = 2.0, -- m/s toward the wall at the top, over the edge
    top_lift = 2.5, -- m/s upward at least, at the top
    max_time = 2.0, -- s, safety limit
}

local SOUND = {
    step = "lcm_fs_sneakers_concrete_sprint", -- a harder step than running: V connects to the wall
    step_interval = 0.15, -- s between footsteps on the wall
}

local wallclimb = {}

---@class Bump
---@field z number world height
---@field depth number m it sticks out from the wall face

local used = false -- one climb per jump: set on entry, cleared on the ground
local missing = 0 -- s the wall has been missing during the climb
local step_timer = 0
local last_vz = 0
local plan_vz = 0 -- m/s, the upward speed V should have now
local slow = 0 -- s V has been well below plan_vz
local nx, ny = 0, 0 -- the wall's normal (horizontal, away from the wall)
local run_up = 0 -- m/s, V's recent horizontal speed (the highest, fading over run_up_time)
---@type Bump[]
local bumps = {}

---@param reason string
local function stop(reason)
    state.mode, state.last_exit = "none", reason
end

-- Velocity change along the wall's normal (away is positive) that moves V toward `hold` from
-- the wall face `dist` away, damped (the push lands a frame late).
---@param dist number
---@param hold number
---@param vn number
---@param delta number
---@return number
local function pull(dist, hold, vn, delta)
    local want =
        -math.min(CLIMB.pull_max, math.max(-CLIMB.pull_max, (dist - hold) * CLIMB.pull_gain))
    return (want - vn) * (1 - math.exp(-delta / CLIMB.pull_time))
end

-- Remember surfaces the upper rays see sticking out from the wall face; forget bumps V is
-- above. Returns how far out the bumps her body is passing stick.
---@param z number V's feet
---@param face number m to the wall face
---@return number
local function update_bumps(z, face)
    for _, key in ipairs({ "ahead_high", "ahead_top" }) do
        local hit = state.walls[key]
        if hit and face - hit.dist > CLIMB.bump_min then
            bumps[#bumps + 1] = { z = z + walls.AHEAD_HEIGHTS[key], depth = face - hit.dist }
        end
    end
    local offset = 0
    ---@type Bump[]
    local kept = {}
    for _, bump in ipairs(bumps) do
        if bump.z > z - 0.1 then
            kept[#kept + 1] = bump
            if bump.z < z + CLIMB.body_height + CLIMB.look_ahead then
                offset = math.max(offset, bump.depth)
            end
        end
    end
    bumps = kept
    return offset
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
        or state.idle < CLIMB.min_idle
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
    local ramp = (into - CLIMB.min_run_up) / (CLIMB.base_run_up - CLIMB.min_run_up)
    local height = CLIMB.base_height * math.max(0, math.min(1, ramp))
        + CLIMB.extra_height * math.max(0, into - CLIMB.base_run_up)
    if height < CLIMB.min_height then
        return false
    end
    plan_vz = math.min(math.sqrt(2 * CLIMB.gravity * height), CLIMB.max_vz)
    used, missing, step_timer, last_vz, slow, bumps = true, 0, 0, plan_vz, 0, {}
    nx, ny = hx, hy
    state.mode, state.side, state.time = "wallclimb", 0, 0
    local vn = v.x * nx + v.y * ny -- away from the wall is positive
    local tx, ty = v.x - vn * nx, v.y - vn * ny -- sideways along the wall: dropped
    local p = -math.min(
            CLIMB.pull_max,
            math.max(0, (hit.dist - CLIMB.hold_dist) * CLIMB.pull_gain)
        ) - vn
    world.impulse(player, p * nx - tx, p * ny - ty, plan_vz - v.z)
    world.sound(player, SOUND.step)
    return true
end

---@param player PlayerPuppet
---@param v Vector4
---@param delta number
function wallclimb.update(player, v, delta)
    state.time = state.time + delta
    plan_vz = plan_vz - CLIMB.gravity * delta
    walls.scan_ahead(player, -nx, -ny)
    local hit = walls.usable("ahead", CLIMB.max_dist)
    local high, top = state.walls.ahead_high, state.walls.ahead_top
    missing = (hit or high or top) and 0 or missing + delta
    local loco = world.locomotion(player)
    local jumped = state.time > 0.1 and v.z - last_vz > CLIMB.jump_detect
    last_vz = v.z
    slow = v.z < plan_vz - CLIMB.blocked_gap and slow + delta or 0
    if loco ~= world.JUMP and loco ~= world.DEFAULT then
        stop("game took over") -- the game's ledge climb, a vault, ...
        return
    elseif jumped then
        stop("jumped") -- V's double jump: keep its boost
        return
    elseif state.time > 0.1 and world.on_ground(player) then
        stop("landed")
        return
    elseif plan_vz <= 0 then
        stop("rise ended")
        return
    elseif slow > CLIMB.blocked_time then
        stop("blocked")
        return
    elseif missing > CLIMB.wall_grace then
        stop("wall ended")
        return
    elseif state.time > CLIMB.max_time then
        stop("time limit")
        return
    end
    if not (hit or high or top) then
        return -- keep the current motion through a short gap
    end
    -- the wall face: the chest ray when it sees the wall, else the farthest upper ray
    local face = hit and hit.dist or math.max(high and high.dist or 0, top and top.dist or 0)
    if hit then
        nx, ny = hit.normal[1], hit.normal[2]
        local length = math.sqrt(nx * nx + ny * ny)
        nx, ny = nx / length, ny / length
    end
    local offset = update_bumps(player:GetWorldPosition().z, face)
    if offset > CLIMB.max_offset then
        stop("overhang")
        return
    end
    local vn = v.x * nx + v.y * ny
    if hit and not high and not top then
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
    local p = pull(face, CLIMB.hold_dist + offset, vn, delta)
    -- upward: the game's gravity minus the climb's, plus following the plan
    local up = (world.GRAVITY - CLIMB.gravity) * delta
        + (plan_vz - v.z) * (1 - math.exp(-delta / CLIMB.follow_time))
    world.impulse(player, p * nx - friction * tx, p * ny - friction * ty, up)
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

settings.section("wall climb", 4, CLIMB, {
    {
        key = "max_angle",
        label = "max angle from head-on (deg)",
        min = 10,
        max = 60,
        format = "%.0f",
    },
    { key = "max_dist", label = "max wall distance (m)", min = 0.6, max = 1.5 },
    { key = "min_run_up", label = "no climb below (m/s)", min = 0, max = 4 },
    { key = "base_run_up", label = "base run-up (m/s)", min = 1.5, max = 7 },
    { key = "base_height", label = "height at base run-up (m)", min = 0.5, max = 3.5 },
    { key = "extra_height", label = "extra height per m/s (m)", min = 0, max = 1 },
    { key = "max_vz", label = "max climb speed (m/s)", min = 4, max = 15 },
    { key = "gravity", label = "gravity on wall (m/s2)", min = 3, max = 16 },
    { key = "run_up_time", label = "run-up memory (s)", min = 0.05, max = 1 },
    { key = "friction", label = "sideways friction (1/s)", min = 0, max = 30 },
    { key = "hold_dist", label = "distance to wall (m)", min = 0.4, max = 0.8 },
    { key = "max_offset", label = "max bump depth (m)", min = 0.2, max = 2 },
    { key = "look_ahead", label = "bump look-ahead (m)", min = 0, max = 1.5 },
    { key = "top_push", label = "push over top (m/s)", min = 0, max = 5 },
    { key = "top_lift", label = "lift at top (m/s)", min = 0, max = 6 },
    {
        key = "step_interval",
        label = "footstep interval (s)",
        min = 0.08,
        max = 0.5,
        values = SOUND,
    },
})

return wallclimb
