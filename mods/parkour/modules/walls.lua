-- Wall rays: to the left and right of V's movement (wall run) and straight ahead along her
-- facing (wall climb), each at chest height and at 2 m to tell tall walls from low ones.
-- Hits go to state.walls.

local state = require("modules/state")
local world = require("modules/world")

local WALL = {
    ray_length = 1.5, -- m from V
    chest = 1.2, -- m above the feet: is there a wall
    high = 2.0, -- m above the feet: is it tall enough
    max_normal_z = 0.3, -- wall normal must be about horizontal
}

local walls = {}

---@param player PlayerPuppet
---@param name string key in state.walls; the high ray goes to name .. "_high"
---@param dx number
---@param dy number
local function cast(player, name, dx, dy)
    local pos = player:GetWorldPosition()
    local tx, ty = pos.x + dx * WALL.ray_length, pos.y + dy * WALL.ray_length
    for _, level in ipairs({
        { suffix = "", height = WALL.chest },
        { suffix = "_high", height = WALL.high },
    }) do
        local z = pos.z + level.height
        state.walls[name .. level.suffix] =
            world.raycast(world.vec(pos.x, pos.y, z), world.vec(tx, ty, z))
    end
end

-- Rays to the right and left of the horizontal unit direction (dx, dy).
---@param player PlayerPuppet
---@param dx number
---@param dy number
function walls.scan_sides(player, dx, dy)
    cast(player, "right", dy, -dx)
    cast(player, "left", -dy, dx)
end

-- Rays straight ahead along the horizontal unit direction (dx, dy).
---@param player PlayerPuppet
---@param dx number
---@param dy number
function walls.scan_ahead(player, dx, dy)
    cast(player, "ahead", dx, dy)
end

-- The hit of ray `name` if it's a wall (about vertical) within max_dist, and whether the wall
-- is tall (the high ray hits too).
---@param name string
---@param max_dist number
---@return WallHit? hit, boolean tall
function walls.usable(name, max_dist)
    local hit = state.walls[name]
    if not hit or hit.dist > max_dist or math.abs(hit.normal[3]) > WALL.max_normal_z then
        return nil, false
    end
    return hit, state.walls[name .. "_high"] ~= nil
end

return walls
