-- parkour (CET): Mirror's Edge style movement for V: wall run, wall climb and momentum.
-- Numbers from our Mirror's Edge captures and the research handbook (datasets/comparison.md),
-- uu converted to metres. Each move is a module in modules/; this file wires them up.
-- Hotkeys "parkour: wall moves on/off", "parkour: momentum on/off". dev-log logs Parkour.state.

local camera = require("modules/camera")
local input = require("modules/input")
local momentum = require("modules/momentum")
local state = require("modules/state")
local wallclimb = require("modules/wallclimb")
local wallrun = require("modules/wallrun")
local walls = require("modules/walls")
local world = require("modules/world")

local Parkour = { state = state }

registerHotkey("parkour_wallrun_toggle", "parkour: wall moves on/off", function()
    state.enabled = not state.enabled
    local player = Game.GetPlayer()
    if not state.enabled and player then
        if state.mode == "wallrun" then
            wallrun.stop(player, "turned off")
        elseif state.mode == "wallclimb" then
            wallclimb.stop()
        end
    end
    world.notify("parkour: wall moves " .. (state.enabled and "on" or "off"))
end)

registerHotkey("parkour_momentum_toggle", "parkour: momentum on/off", function()
    state.momentum = not state.momentum
    world.notify("parkour: momentum " .. (state.momentum and "on" or "off"))
end)

registerForEvent("onInit", function()
    input.observe()
end)

registerForEvent("onShutdown", function()
    local player = Game.GetPlayer()
    if player then
        momentum.clear(player)
    end
end)

---@param delta number
registerForEvent("onUpdate", function(delta)
    local player = Game.GetPlayer()
    if not player or not player:IsAttached() or delta <= 0 then
        return
    end
    local v = world.velocity(player)
    if v then
        -- side walls relative to movement when moving, else relative to facing
        local speed = math.sqrt(v.x * v.x + v.y * v.y)
        local dx, dy = world.facing(player)
        if speed > 0.5 then
            dx, dy = v.x / speed, v.y / speed
        end
        walls.scan_sides(player, dx, dy)
        if state.mode == "wallrun" then
            wallrun.update(player, v, delta)
        elseif state.mode == "wallclimb" then
            wallclimb.update(player, v, delta)
        elseif state.enabled then
            if not wallclimb.try_start(player, v, delta) then
                wallrun.try_start(player, v, delta)
            end
        end
        momentum.update(player, v, delta)
    end
    camera.update(player, delta)
end)

return Parkour
