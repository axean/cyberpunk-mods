-- dev-log (CET): writes V's movement a few times per second to dev_log.jsonl in this mod's
-- folder, one JSON object per line, so it can be read while playing. The file starts fresh
-- each time the game starts or CET reloads mods.

local INTERVAL = 0.25 -- seconds between lines

---@type file*?
local file = nil
local time = 0
local next_write = 0

---@param player PlayerPuppet
---@return integer locomotion, integer high_level
local function locomotion_state(player)
    local defs = GetAllBlackboardDefs().PlayerStateMachine
    local bb = Game.GetBlackboardSystem():GetLocalInstanced(player:GetEntityID(), defs)
    return bb:GetInt(defs.Locomotion), bb:GetInt(defs.HighLevel)
end

---@param player PlayerPuppet
---@return string
local function line(player)
    local pos = player:GetWorldPosition()
    local vel = player:GetVelocity()
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
    local ok, loco, high = pcall(locomotion_state, player)
    if not ok then
        loco, high = -1, -1
    end
    return string.format(
        '{"t":%.2f,"pos":[%.2f,%.2f,%.2f],"vel":[%.2f,%.2f,%.2f],"speed":%.2f,"yaw":%.1f,'
            .. '"locomotion":%d,"high_level":%d}\n',
        time,
        pos.x,
        pos.y,
        pos.z,
        vel.x,
        vel.y,
        vel.z,
        speed,
        player:GetWorldYaw(),
        loco,
        high
    )
end

registerForEvent("onInit", function()
    file = io.open("dev_log.jsonl", "w")
end)

---@param delta number
registerForEvent("onUpdate", function(delta)
    time = time + delta
    if not file or time < next_write then
        return
    end
    next_write = time + INTERVAL
    local player = Game.GetPlayer()
    if player and player:IsAttached() then
        file:write(line(player))
        file:flush()
    end
end)

registerForEvent("onShutdown", function()
    if file then
        file:close()
    end
end)
