-- parkour (CET): Mirror's Edge style movement. For now, three spikes for the wall run:
--   hover  (hold): cancel V's vertical speed every frame with impulses
--   walls  (always): raycasts left and right of V, results in Parkour.state.walls (dev-log logs them)
--   roll   (hold): roll the view toward ROLL_MAX and lift it, back to level on release

local RAY_GROUPS = { "Static", "Terrain", "PlayerBlocker", "Vehicle" }
local RAY_LENGTH = 1.5 -- m, sideways from V's centre line
local CHEST, HIGH = 1.2, 2.0 -- m above the feet: wall check, wall height check
local ROLL_MAX, ROLL_IN, ROLL_OUT = 20, 30, 100 -- degrees, degrees per second in and out
local EYE_LIFT = 0.1 -- m while rolling
local MAX_PLAUSIBLE_SPEED = 100 -- m/s; GetVelocity() sometimes returns nonsense

---@class WallHit
---@field dist number
---@field normal number[]

---@class ParkourState
---@field walls table<string, WallHit> hits by ray: left, right, left_high, right_high
---@field hover boolean
---@field roll number

local Parkour = {
    ---@type ParkourState
    state = { walls = {}, hover = false, roll = 0 },
}
local roll_held = false

---@param x number
---@param y number
---@param z number
---@return Vector4
local function vec(x, y, z)
    return Vector4.new(x, y, z, 1)
end

-- Closest hit of a ray over the collision groups walls can be in.
---@param from Vector4
---@param to Vector4
---@return WallHit?
local function raycast(from, to)
    local spatial = Game.GetSpatialQueriesSystem()
    ---@type WallHit?
    local best = nil
    for _, group in ipairs(RAY_GROUPS) do
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

---@param player PlayerPuppet
local function scan_walls(player)
    local pos, fwd = player:GetWorldPosition(), player:GetWorldForward()
    local length = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
    if length < 1e-3 then
        return
    end
    -- right-hand side of V's facing, horizontal
    local rx, ry = fwd.y / length * RAY_LENGTH, -fwd.x / length * RAY_LENGTH
    local walls = Parkour.state.walls
    for _, side in ipairs({ { name = "right", sign = 1 }, { name = "left", sign = -1 } }) do
        for _, level in ipairs({
            { suffix = "", height = CHEST },
            { suffix = "_high", height = HIGH },
        }) do
            local z = pos.z + level.height
            local to = vec(pos.x + side.sign * rx, pos.y + side.sign * ry, z)
            walls[side.name .. level.suffix] = raycast(vec(pos.x, pos.y, z), to)
        end
    end
end

---@param player PlayerPuppet
---@param dz number
local function impulse(player, dz)
    local event = PSMImpulse.new()
    event.id = "impulse"
    event.impulse = Vector4.new(0, 0, dz, 1)
    player:QueueEvent(event)
end

---@param player PlayerPuppet
local function hover(player)
    local vel = player:GetVelocity()
    if math.abs(vel.z) <= MAX_PLAUSIBLE_SPEED and math.abs(vel.z) > 0.01 then
        impulse(player, -vel.z)
    end
end

---@param player PlayerPuppet
---@param delta number
local function update_roll(player, delta)
    local s = Parkour.state
    local target = roll_held and ROLL_MAX or 0
    local rate = roll_held and ROLL_IN or ROLL_OUT
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
    camera:SetLocalPosition(Vector4.new(0, 0, EYE_LIFT * s.roll / ROLL_MAX, 0))
end

registerInput("parkour_spike_hover", "parkour spike: hover (hold)", function(down)
    Parkour.state.hover = down
end)

registerInput("parkour_spike_roll", "parkour spike: roll camera (hold)", function(down)
    roll_held = down
end)

---@param delta number
registerForEvent("onUpdate", function(delta)
    local player = Game.GetPlayer()
    if not player or not player:IsAttached() then
        return
    end
    scan_walls(player)
    if Parkour.state.hover then
        hover(player)
    end
    update_roll(player, delta)
end)

return Parkour
