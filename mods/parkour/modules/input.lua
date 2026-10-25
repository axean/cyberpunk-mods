-- Movement input, controller and keyboard: the stick sends MoveX / MoveY axis values (WASD
-- too, but not reliably, so the keys are also tracked as buttons, like Wall Hang does).
-- Writes state.input, state.sprint_button and state.jump_pressed.

local state = require("modules/state")

local input = {}

local stick = { 0, 0 }
---@type table<string, boolean>
local keys = { Forward = false, Back = false, Left = false, Right = false }

local function update()
    local x = (keys.Right and 1 or 0) - (keys.Left and 1 or 0)
    local y = (keys.Forward and 1 or 0) - (keys.Back and 1 or 0)
    if x == 0 and y == 0 then
        x, y = stick[1], stick[2]
    end
    state.input = { x, y }
end

-- Start listening; call from onInit.
function input.observe()
    Observe("PlayerPuppet", "OnAction", function(_, action)
        ---@cast action ListenerAction
        local name = Game.NameToString(action:GetName())
        if name == "MoveX" then
            stick[1] = tonumber(action:GetValue()) or 0
        elseif name == "MoveY" then
            stick[2] = tonumber(action:GetValue()) or 0
        elseif name == "Jump" then
            if action:GetType() == gameinputActionType.BUTTON_PRESSED then
                state.jump_pressed = true
            end
            return
        elseif name == "Sprint" or name == "ToggleSprint" then
            state.sprint_button = (tonumber(action:GetValue()) or 0) > 0
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
        update()
    end)
    Observe("PlayerPuppet", "OnGameAttached", function(self)
        self:RegisterInputListener(self)
    end)
    local player = Game.GetPlayer()
    if player then
        player:RegisterInputListener(player) -- after "Reload all mods" in a running game
    end
end

-- Is the stick deflected at least min_input and pointing within max_angle degrees of the
-- horizontal direction (dx, dy)? The stick is relative to where V faces.
---@param player PlayerPuppet
---@param dx number
---@param dy number
---@param min_input number
---@param max_angle number
---@return boolean
function input.along(player, dx, dy, min_input, max_angle)
    local x, y = state.input[1], state.input[2]
    if math.sqrt(x * x + y * y) < min_input then
        return false
    end
    local f = player:GetWorldForward()
    local wx, wy = x * f.y + y * f.x, -x * f.x + y * f.y -- right = (f.y, -f.x)
    local w = math.sqrt(wx * wx + wy * wy)
    return w > 1e-3 and (wx * dx + wy * dy) / w >= math.cos(math.rad(max_angle))
end

return input
