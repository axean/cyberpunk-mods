-- parkour (CET): Mirror's Edge style movement. Milestone 1: the wall run sticks.
--
-- Jump next to a tall wall while moving along it and V runs along the wall: lifted on entry,
-- then lower gravity (rising 8.2, falling 5.0 m/s² instead of 16), a little speed loss, the
-- view tilted away from the wall, footsteps. Ends when V falls too fast, the wall ends, or V
-- lands; V's double jump on the wall becomes a jump away from it.
-- Numbers from our Mirror's Edge captures (datasets/comparison.md), uu converted to metres.
-- Hotkey "parkour: wall run on/off". dev-log logs Parkour.state.

local GRAVITY = 16 -- m/s², the game's defaultGravity

local WALL = {
    ray_length = 1.5, -- m, sideways from V
    chest = 1.2, -- m above the feet: is there a wall beside V
    high = 2.0, -- m above the feet: is it tall enough
    max_dist = 1.0, -- m from V to the wall to start or keep running
    max_normal_z = 0.3, -- wall normal must be about horizontal
    groups = { "Static", "Terrain", "PlayerBlocker", "Vehicle" },
}

local RUN = {
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
    step = "lcm_fs_sneakers_concrete_run",
    step_interval = 0.28, -- s between footsteps on the wall
}

local CAMERA = {
    roll_max = 22, -- degrees, tilted away from the wall
    roll_in = 30, -- degrees per second while on the wall
    roll_out = 100, -- degrees per second back to level
    eye_lift = 0.1, -- m while on the wall
}

local GROUND_PROBE = 0.15 -- m below the feet that counts as standing on something
local MAX_PLAUSIBLE_SPEED = 100 -- m/s; GetVelocity() sometimes returns nonsense
local JUMP = 5 -- locomotion state value the game writes for all jumps

---@class WallHit
---@field dist number
---@field normal number[]

---@class ParkourState
---@field enabled boolean
---@field mode string "none" or "wallrun"
---@field side integer wall side: -1 left, 1 right, 0 none
---@field time number seconds in the current wall run
---@field last_exit string why the last wall run ended
---@field walls table<string, WallHit> hits by ray: left, right, left_high, right_high
---@field roll number camera roll in degrees, positive = right side down

local Parkour = {
    ---@type ParkourState
    state = {
        enabled = true,
        mode = "none",
        side = 0,
        time = 0,
        last_exit = "",
        walls = {},
        roll = 0,
    },
}
local cooldown = 0
local missing = 0 -- s the wall has been missing during the run
local step_timer = 0
---@type number[]? velocity along the wall (x, y) and upward speed in the previous frame
local last = nil

---@param x number
---@param y number
---@param z number
---@return Vector4
local function vec(x, y, z)
    return Vector4.new(x, y, z, 1)
end

---@param player PlayerPuppet
---@return integer
local function locomotion(player)
    local defs = GetAllBlackboardDefs().PlayerStateMachine
    return Game.GetBlackboardSystem()
        :GetLocalInstanced(player:GetEntityID(), defs)
        :GetInt(defs.Locomotion)
end

---@param player PlayerPuppet
---@return Vector4?
local function velocity(player)
    local v = player:GetVelocity()
    if math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) > MAX_PLAUSIBLE_SPEED then
        return nil
    end
    return v
end

-- Closest hit of a ray over the collision groups walls can be in.
---@param from Vector4
---@param to Vector4
---@return WallHit?
local function raycast(from, to)
    local spatial = Game.GetSpatialQueriesSystem()
    ---@type WallHit?
    local best = nil
    for _, group in ipairs(WALL.groups) do
        local ok, hit, result =
            pcall(spatial.SyncRaycastByCollisionGroup, spatial, from, to, group, false, false)
        if ok and hit and result then
            local p = result.position
            local dist = math.sqrt((p.x - from.x) ^ 2 + (p.y - from.y) ^ 2 + (p.z - from.z) ^ 2)
            if not best or dist < best.dist then
                local n = result.normal
                best = { dist = dist, normal = { n.x, n.y, n.z } }
            end
        end
    end
    return best
end

-- Rays to the left and right of the direction (dx, dy), at chest height and at WALL.high.
---@param player PlayerPuppet
---@param dx number
---@param dy number
local function scan_walls(player, dx, dy)
    local pos = player:GetWorldPosition()
    local rx, ry = dy * WALL.ray_length, -dx * WALL.ray_length -- right-hand side
    local walls = Parkour.state.walls
    for _, side in ipairs({ { name = "right", sign = 1 }, { name = "left", sign = -1 } }) do
        for _, level in ipairs({
            { suffix = "", height = WALL.chest },
            { suffix = "_high", height = WALL.high },
        }) do
            local z = pos.z + level.height
            local to = vec(pos.x + side.sign * rx, pos.y + side.sign * ry, z)
            walls[side.name .. level.suffix] = raycast(vec(pos.x, pos.y, z), to)
        end
    end
end

-- A short ray down from V's feet. (The game's Jump state ends after ~0.7 s even in the air,
-- so the locomotion state can't tell whether V landed.)
---@param player PlayerPuppet
---@return boolean
local function on_ground(player)
    local pos = player:GetWorldPosition()
    return raycast(vec(pos.x, pos.y, pos.z + 0.1), vec(pos.x, pos.y, pos.z - GROUND_PROBE)) ~= nil
end

---@param name string "left" or "right"
---@return WallHit? hit, boolean tall
local function usable_wall(name)
    local walls = Parkour.state.walls
    local hit = walls[name]
    if not hit or hit.dist > WALL.max_dist or math.abs(hit.normal[3]) > WALL.max_normal_z then
        return nil, false
    end
    return hit, walls[name .. "_high"] ~= nil
end

---@param player PlayerPuppet
---@param x number
---@param y number
---@param z number
local function impulse(player, x, y, z)
    local event = PSMImpulse.new()
    event.id = "impulse"
    event.impulse = Vector4.new(x, y, z, 1)
    player:QueueEvent(event)
end

---@param player PlayerPuppet
---@param name string
local function sound(player, name)
    local event = SoundPlayEvent.new()
    event.soundName = name
    player:QueueEvent(event)
end

---@param player PlayerPuppet
---@param reason string
local function stop(player, reason)
    local s = Parkour.state
    s.mode, s.side, s.last_exit = "none", 0, reason
    cooldown = RUN.cooldown
    sound(player, SOUND.exit)
end

---@param player PlayerPuppet
---@param v Vector4
local function try_start(player, v)
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    if speed < RUN.min_speed or v.z < RUN.min_entry_vz or locomotion(player) ~= JUMP then
        return
    end
    for _, side in ipairs({ { name = "right", sign = 1 }, { name = "left", sign = -1 } }) do
        local hit, tall = usable_wall(side.name)
        if hit and tall then
            local nx, ny = hit.normal[1], hit.normal[2]
            local vn = v.x * nx + v.y * ny -- away from the wall is positive
            local into = -vn / speed -- sine of the angle to the wall, positive = toward it
            if into >= -0.2 and into <= math.sin(math.rad(RUN.max_angle)) then
                local s = Parkour.state
                s.mode, s.side, s.time = "wallrun", side.sign, 0
                missing, step_timer, last = 0, 0, nil
                -- lift, and drop the velocity component into or away from the wall
                impulse(player, -vn * nx, -vn * ny, RUN.lift - v.z)
                sound(player, SOUND.enter)
                return
            end
        end
    end
end

---@param player PlayerPuppet
---@param v Vector4
---@param delta number
local function run(player, v, delta)
    local s = Parkour.state
    s.time = s.time + delta
    local hit = usable_wall(s.side == 1 and "right" or "left")
    missing = hit and 0 or missing + delta
    if missing > RUN.wall_grace then
        stop(player, "wall ended")
        return
    elseif v.z < RUN.exit_vz then
        stop(player, "fell off")
        return
    elseif s.time > 0.1 and v.z <= 0 and on_ground(player) then
        stop(player, "landed")
        return
    elseif s.time > RUN.max_time then
        stop(player, "time limit")
        return
    end
    if not hit then
        return -- keep the current motion through a short gap
    end
    local nx, ny = hit.normal[1], hit.normal[2]
    local vn = v.x * nx + v.y * ny -- away from the wall is positive
    local tx, ty = v.x - vn * nx, v.y - vn * ny -- along the wall
    if last and s.time > 0.08 and v.z - last[3] > RUN.jump_detect then
        -- V's double jump: turn it into a jump off the wall, keeping the speed along it
        impulse(
            player,
            last[1] + RUN.jump_away * nx - v.x,
            last[2] + RUN.jump_away * ny - v.y,
            RUN.jump_up - v.z
        )
        stop(player, "jumped off")
        return
    end
    last = { tx, ty, v.z }
    local gravity = v.z > 0 and RUN.gravity_up or RUN.gravity_down
    local stick = RUN.stick_gain * (-RUN.stick_speed - vn)
    local friction = RUN.friction * delta
    impulse(
        player,
        stick * nx - friction * tx,
        stick * ny - friction * ty,
        (GRAVITY - gravity) * delta
    )
    step_timer = step_timer + delta
    if step_timer >= SOUND.step_interval then
        step_timer = step_timer - SOUND.step_interval
        sound(player, SOUND.step)
    end
end

---@param player PlayerPuppet
---@param delta number
local function update_camera(player, delta)
    local s = Parkour.state
    local target = -s.side * CAMERA.roll_max -- tilt away from the wall
    local rate = s.side ~= 0 and CAMERA.roll_in or CAMERA.roll_out
    local before = s.roll
    if s.roll < target then
        s.roll = math.min(target, s.roll + rate * delta)
    else
        s.roll = math.max(target, s.roll - rate * delta)
    end
    if s.roll == 0 and before == 0 then
        return
    end
    -- roll about the camera's forward (local Y) axis
    local half = math.rad(s.roll) / 2
    local camera = player:GetFPPCameraComponent()
    camera:SetLocalOrientation(Quaternion.new(0, math.sin(half), 0, math.cos(half)))
    camera:SetLocalPosition(
        Vector4.new(0, 0, CAMERA.eye_lift * math.abs(s.roll) / CAMERA.roll_max, 0)
    )
end

-- On-screen message in the game (the HUD's notification line), for hotkey feedback.
---@param text string
local function notify(text)
    local message = SimpleScreenMessage.new()
    message.message, message.duration, message.isShown = text, 2, true
    local defs = GetAllBlackboardDefs().UI_Notifications
    Game.GetBlackboardSystem():Get(defs):SetVariant(defs.OnscreenMessage, ToVariant(message), true)
end

registerHotkey("parkour_wallrun_toggle", "parkour: wall run on/off", function()
    local s = Parkour.state
    s.enabled = not s.enabled
    local player = Game.GetPlayer()
    if not s.enabled and s.mode ~= "none" and player then
        stop(player, "turned off")
    end
    local text = "parkour: wall run " .. (s.enabled and "on" or "off")
    print(text)
    pcall(notify, text)
end)

---@param delta number
registerForEvent("onUpdate", function(delta)
    local player = Game.GetPlayer()
    if not player or not player:IsAttached() or delta <= 0 then
        return
    end
    local v = velocity(player)
    if v then
        -- scan relative to movement when moving, else relative to facing
        local speed = math.sqrt(v.x * v.x + v.y * v.y)
        local dir = player:GetWorldForward()
        local dx, dy = dir.x, dir.y
        if speed > 0.5 then
            dx, dy = v.x / speed, v.y / speed
        end
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 1e-3 then
            scan_walls(player, dx / length, dy / length)
        end
        cooldown = math.max(0, cooldown - delta)
        local s = Parkour.state
        if s.mode == "wallrun" then
            run(player, v, delta)
        elseif s.enabled and cooldown == 0 then
            try_start(player, v)
        end
    end
    update_camera(player, delta)
end)

return Parkour
