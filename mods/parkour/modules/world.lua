-- Game queries and effects the moves share: V's velocity and movement state, raycasts, pushes,
-- sounds and on-screen messages.

local world = {}

world.GRAVITY = 16 -- m/s², the game's defaultGravity
-- Locomotion values as the game writes them (the decompiled enum is off by one from 4 on).
world.DEFAULT, world.SPRINT, world.JUMP, world.DODGE, world.DODGE_AIR = 0, 2, 5, 7, 8

local GROUND_PROBE = 0.15 -- m below the feet that counts as standing on something
local MAX_PLAUSIBLE_SPEED = 100 -- m/s; GetVelocity() sometimes returns nonsense
local GROUPS = { "Static", "Terrain", "PlayerBlocker", "Vehicle" } -- what walls and floors are

---@param x number
---@param y number
---@param z number
---@return Vector4
function world.vec(x, y, z)
    return Vector4.new(x, y, z, 1)
end

---@param player PlayerPuppet
---@return integer
function world.locomotion(player)
    local defs = GetAllBlackboardDefs().PlayerStateMachine
    return Game.GetBlackboardSystem()
        :GetLocalInstanced(player:GetEntityID(), defs)
        :GetInt(defs.Locomotion)
end

---@param player PlayerPuppet
---@return Vector4?
function world.velocity(player)
    local v = player:GetVelocity()
    if math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) > MAX_PLAUSIBLE_SPEED then
        return nil
    end
    return v
end

-- V's horizontal facing as a unit vector.
---@param player PlayerPuppet
---@return number, number
function world.facing(player)
    local f = player:GetWorldForward()
    local length = math.sqrt(f.x * f.x + f.y * f.y)
    if length < 1e-3 then
        return 0, 1
    end
    return f.x / length, f.y / length
end

-- Closest hit of a ray over the collision groups walls and floors can be in.
---@param from Vector4
---@param to Vector4
---@return WallHit?
function world.raycast(from, to)
    local spatial = Game.GetSpatialQueriesSystem()
    ---@type WallHit?
    local best = nil
    for _, group in ipairs(GROUPS) do
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

-- A short ray down from V's feet. (The game's Jump state ends after ~0.7 s even in the air,
-- so the locomotion state can't tell whether V landed.)
---@param player PlayerPuppet
---@return boolean
function world.on_ground(player)
    local pos = player:GetWorldPosition()
    local from, to =
        world.vec(pos.x, pos.y, pos.z + 0.1), world.vec(pos.x, pos.y, pos.z - GROUND_PROBE)
    return world.raycast(from, to) ~= nil
end

-- Change V's velocity by (x, y, z) m/s. Only in the air: on the ground a push in the frame a
-- dash starts replaces the dash's own boost.
---@param player PlayerPuppet
---@param x number
---@param y number
---@param z number
function world.impulse(player, x, y, z)
    local event = PSMImpulse.new()
    event.id = "impulse"
    event.impulse = Vector4.new(x, y, z, 1)
    player:QueueEvent(event)
end

---@param player PlayerPuppet
---@param name string
function world.sound(player, name)
    local event = SoundPlayEvent.new()
    event.soundName = name
    player:QueueEvent(event)
end

-- On-screen message in the game (the HUD's notification line), for hotkey feedback.
---@param text string
function world.notify(text)
    print(text)
    pcall(function()
        local message = SimpleScreenMessage.new()
        message.message, message.duration, message.isShown = text, 2, true
        local defs = GetAllBlackboardDefs().UI_Notifications
        Game.GetBlackboardSystem()
            :Get(defs)
            :SetVariant(defs.OnscreenMessage, ToVariant(message), true)
    end)
end

return world
