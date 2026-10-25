-- Momentum: on the ground the mod moves the game's own speed cap and acceleration for V (stat
-- modifiers, no pushing, so the game's dash and jump boosts stay intact): she gets into a sprint
-- over a moment, keeps her speed through landings and after a dash, and turns wider at speed.
--
-- The game caps V's speed per movement state (PlayerLocomotion.player_locomotion_data_<state>):
-- sprint 7.5, jog 3.5, in the air 4.5 but braking only 1.3 m/s², landing 4.5 braking 24. So
-- V keeps her speed through a jump and loses it at touchdown. The mod sets her cap to the
-- tracked speed (state.carry) instead, which changes only at the rates below.

local input = require("modules/input")
local state = require("modules/state")
local world = require("modules/world")

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

local momentum = {}

local airborne = false
local air_vz = 0 -- m/s, V's vertical speed in the last airborne frame
local last_speed = 0 -- m/s, V's horizontal speed in the previous frame
local settle = 0 -- s left before speed drops count as impacts
local after_dash = false -- a dash happened since V was last on the ground jogging or sprinting
---@type gameStatModifierData[]
local modifiers = {} -- the mod's stat modifiers on V
local applied = { cap = 0, accel = 0 } -- what they add to MaxSpeed and Acceleration

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

-- Remove the mod's stat modifiers from V (on shutdown).
---@param player PlayerPuppet
function momentum.clear(player)
    set_stats(player, 0, 0)
end

-- In the air and in other moves (dash, slide, vault, wall moves) the game's own stats apply and
-- the carried speed is V's. On the ground (jog or sprint) the carried speed becomes her cap: it
-- builds toward the game's cap, and fades slowly when above it.
---@param player PlayerPuppet
---@param v Vector4
---@param delta number
function momentum.update(player, v, delta)
    local speed = math.sqrt(v.x * v.x + v.y * v.y)
    local dropped = last_speed - speed
    last_speed = speed
    local loco = world.locomotion(player)
    local grounded = world.on_ground(player)
    if
        not state.momentum
        or state.mode ~= "none"
        or (loco ~= world.DEFAULT and loco ~= world.SPRINT)
        or not grounded
    then
        state.carry, settle = speed, MOMENTUM.settle_time
        after_dash = after_dash or loco == world.DODGE or loco == world.DODGE_AIR
        set_stats(player, 0, 0)
        airborne = not grounded
        if airborne then
            air_vz = v.z
        end
        return
    end
    settle = math.max(0, settle - delta)
    local carry = state.carry
    if airborne then
        airborne = false
        carry = air_vz < MOMENTUM.hard_landing_vz and speed or carry - MOMENTUM.landing_loss
    end
    if settle == 0 and dropped > MOMENTUM.impact_drop then
        state.impact = dropped -- ran into something
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
    elseif
        speed > 0.5
        and input.along(
            player,
            v.x / speed,
            v.y / speed,
            MOMENTUM.min_input,
            MOMENTUM.max_input_angle
        )
    then
        carry = math.max(base, carry - MOMENTUM.keep_decel * delta)
    else
        carry = base
    end
    state.carry = carry
    local accel = stats:GetStatValue(id, gamedataStatType.Acceleration) - applied.accel
    set_stats(player, carry - base, math.min(0, MOMENTUM.turn_accel - accel))
end

return momentum
