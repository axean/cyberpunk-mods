-- parkour (CET): Mirror's Edge style movement: the wall run, and momentum.
--
-- Jump next to a tall wall while moving along it and V runs along the wall: lifted on entry,
-- then lower gravity (rising 8.2, falling 5.0 m/s² instead of 16), a little speed loss, the
-- view tilted away from the wall, footsteps. Ends when V falls too fast, the wall ends, or V
-- lands; V's double jump on the wall becomes a jump away from it.
-- Momentum: on the ground the mod moves the game's own speed cap and acceleration for V (stat
-- modifiers, no pushing, so the game's dash and jump boosts stay intact): she gets into a sprint
-- over a moment, keeps her speed through landings and after a dash, and turns wider at speed.
-- Numbers from our Mirror's Edge captures (datasets/comparison.md), uu converted to metres.
-- Hotkeys "parkour: wall run on/off", "parkour: momentum on/off". dev-log logs Parkour.state.

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

-- The game caps V's speed per movement state (PlayerLocomotion.player_locomotion_data_<state>):
-- sprint 7.5, jog 3.5, in the air 4.5 but braking only 1.3 m/s², landing 4.5 braking 24. So
-- V keeps her speed through a jump and loses it at touchdown. The mod sets her cap to the
-- tracked speed ("carry") instead, which changes only at the rates below.
local MOMENTUM = {
    free_speed = 4.0, -- m/s, up to this V speeds up as the game lets her (walking, jogging)
    build_time = 1.0, -- s, above free_speed the cap approaches the sprint at this time constant
    lead = 1.0, -- m/s, most the cap may be above V's actual speed (when she slows, it follows)
    landing_loss = 0.65, -- m/s lost per landing (Mirror's Edge LandingSpeedReduction, 65 uu/s)
    keep_decel = 3.0, -- m/s², speed above the game's cap fades this fast while the stick points on
    dash_keep = 0.8, -- share of a dash's speed above the cap that is carried on after it
    turn_accel = 15, -- m/s², V's acceleration on the ground (game: 24); turns at speed are wider
    impact_drop = 4.0, -- m/s lost from one frame to the next: she hit something (logged)
    settle_time = 0.3, -- s after a dash, jump etc. before a speed drop counts as an impact
    hard_landing_vz = -13, -- m/s, landing faster than this keeps nothing (Mirror's Edge: 5.3 m)
    min_input = 0.5, -- stick deflection that counts as moving on
    max_input_angle = 60, -- degrees between the stick direction and V's movement to keep speed
}

local GROUND_PROBE = 0.15 -- m below the feet that counts as standing on something
local MAX_PLAUSIBLE_SPEED = 100 -- m/s; GetVelocity() sometimes returns nonsense
local DEFAULT, SPRINT, JUMP, DODGE, DODGE_AIR = 0, 2, 5, 7, 8 -- locomotion values; JUMP: all jumps

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
---@field momentum boolean momentum on
---@field carry number m/s, V's speed cap as the mod sets it on the ground
---@field impact number m/s lost in the last impact
---@field input number[] stick: right, forward (-1..1)
---@field sprint_button boolean sprint (or toggle sprint) button down

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
        momentum = true,
        carry = 0,
        impact = 0,
        input = { 0, 0 },
        sprint_button = false,
    },
}
local cooldown = 0
local missing = 0 -- s the wall has been missing during the run
local step_timer = 0
---@type number[]? velocity along the wall (x, y) and upward speed in the previous frame
local last = nil
local airborne = false
local air_vz = 0 -- m/s, V's vertical speed in the last airborne frame
local last_speed = 0 -- m/s, V's horizontal speed in the previous frame
local settle = 0 -- s left before speed drops count as impacts
local after_dash = false -- a dash happened since V was last on the ground jogging or sprinting
---@type gameStatModifierData[]
local modifiers = {} -- the mod's stat modifiers on V
local applied = { cap = 0, accel = 0 } -- what they add to MaxSpeed and Acceleration

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

-- Is the stick pointing roughly along V's horizontal movement (dx, dy)?
---@param player PlayerPuppet
---@param dx number
---@param dy number
---@return boolean
local function input_along(player, dx, dy)
    local x, y = Parkour.state.input[1], Parkour.state.input[2]
    if math.sqrt(x * x + y * y) < MOMENTUM.min_input then
        return false
    end
    local f = player:GetWorldForward()
    local wx, wy = x * f.y + y * f.x, -x * f.x + y * f.y -- right = (f.y, -f.x)
    local w = math.sqrt(wx * wx + wy * wy)
    return w > 1e-3 and (wx * dx + wy * dy) / w >= math.cos(math.rad(MOMENTUM.max_input_angle))
end

-- Replace the mod's additive MaxSpeed and Acceleration modifiers on V (if they changed).
---@param player PlayerPuppet
---@param cap number
---@param accel number
local function set_stats(player, cap, accel)
    if math.abs(cap - applied.cap) < 0.05 and math.abs(accel - applied.accel) < 0.05 then
        return
    end
    local stats = Game.GetStatsSystem()
    local id = player:GetEntityID()
    for _, modifier in ipairs(modifiers) do
        stats:RemoveModifier(id, modifier)
    end
    modifiers = {}
    for _, add in ipairs({
        { gamedataStatType.MaxSpeed, cap },
        { gamedataStatType.Acceleration, accel },
    }) do
        if add[2] ~= 0 then
            local modifier =
                RPGManager.CreateStatModifier(add[1], gameStatModifierType.Additive, add[2])
            stats:AddModifier(id, modifier)
            modifiers[#modifiers + 1] = modifier
        end
    end
    applied.cap, applied.accel = cap, accel
end

-- Momentum: in the air and in other moves (dash, slide, vault, wall run) the game's own stats
-- apply and the carried speed is V's. On the ground (jog or sprint) the carried speed becomes
-- her cap: it builds toward the game's cap, and fades slowly when above it.
---@param player PlayerPuppet
---@param v Vector4
---@param delta number
local function momentum(player, v, delta)
    local s = Parkour.state
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    local dropped = last_speed - speed
    last_speed = speed
    local loco = locomotion(player)
    local grounded = on_ground(player)
    if
        not s.momentum
        or s.mode ~= "none"
        or (loco ~= DEFAULT and loco ~= SPRINT)
        or not grounded
    then
        s.carry, settle = speed, MOMENTUM.settle_time
        after_dash = after_dash or loco == DODGE or loco == DODGE_AIR
        set_stats(player, 0, 0)
        airborne = not grounded
        if airborne then
            air_vz = v.z
        end
        return
    end
    settle = math.max(0, settle - delta)
    local carry = s.carry
    if airborne then
        airborne = false
        carry = air_vz < MOMENTUM.hard_landing_vz and speed or carry - MOMENTUM.landing_loss
    end
    if settle == 0 and dropped > MOMENTUM.impact_drop then
        s.impact = dropped -- ran into something
    end
    carry = math.min(carry, speed + MOMENTUM.lead)
    local stats = Game.GetStatsSystem()
    local id = player:GetEntityID()
    local base = stats:GetStatValue(id, gamedataStatType.MaxSpeed) - applied.cap
    if after_dash then
        after_dash = false
        if carry > base then
            carry = base + (carry - base) * MOMENTUM.dash_keep
        end
    end
    if base > carry then
        -- getting into it: free up to free_speed, then a smooth approach
        local from = math.min(base, math.max(carry, MOMENTUM.free_speed))
        carry = from + (base - from) * (1 - math.exp(-delta / MOMENTUM.build_time))
    elseif speed > 0.5 and input_along(player, v.x / speed, v.y / speed) then
        carry = math.max(base, carry - MOMENTUM.keep_decel * delta)
    else
        carry = base
    end
    s.carry = carry
    local accel = stats:GetStatValue(id, gamedataStatType.Acceleration) - applied.accel
    set_stats(player, carry - base, math.min(0, MOMENTUM.turn_accel - accel))
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

registerHotkey("parkour_momentum_toggle", "parkour: momentum on/off", function()
    local s = Parkour.state
    s.momentum = not s.momentum
    local text = "parkour: momentum " .. (s.momentum and "on" or "off")
    print(text)
    pcall(notify, text)
end)

-- Movement input, controller and keyboard: the stick sends MoveX / MoveY axis values (WASD
-- too, but not reliably, so the keys are also tracked as buttons, like Wall Hang does).
local stick = { 0, 0 }
---@type table<string, boolean>
local keys = { Forward = false, Back = false, Left = false, Right = false }

local function update_input()
    local x = (keys.Right and 1 or 0) - (keys.Left and 1 or 0)
    local y = (keys.Forward and 1 or 0) - (keys.Back and 1 or 0)
    if x == 0 and y == 0 then
        x, y = stick[1], stick[2]
    end
    Parkour.state.input = { x, y }
end

registerForEvent("onShutdown", function()
    local player = Game.GetPlayer()
    if player then
        set_stats(player, 0, 0)
    end
end)

registerForEvent("onInit", function()
    Observe("PlayerPuppet", "OnAction", function(_, action)
        ---@cast action ListenerAction
        local name = Game.NameToString(action:GetName())
        if name == "MoveX" then
            stick[1] = tonumber(action:GetValue()) or 0
        elseif name == "MoveY" then
            stick[2] = tonumber(action:GetValue()) or 0
        elseif name == "Sprint" or name == "ToggleSprint" then
            Parkour.state.sprint_button = (tonumber(action:GetValue()) or 0) > 0
            return
        elseif keys[name] ~= nil then
            local kind = action:GetType()
            if kind == gameinputActionType.BUTTON_PRESSED then
                keys[name] = true
            elseif kind == gameinputActionType.BUTTON_RELEASED then
                keys[name] = false
            end
        else
            return
        end
        update_input()
    end)
    Observe("PlayerPuppet", "OnGameAttached", function(self)
        self:RegisterInputListener(self)
    end)
    local player = Game.GetPlayer()
    if player then
        player:RegisterInputListener(player) -- after "Reload all mods" in a running game
    end
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
        momentum(player, v, delta)
    end
    update_camera(player, delta)
end)

return Parkour
