-- dev-log (CET): writes V's movement a few times per second to dev_log.jsonl in this mod's
-- folder, one JSON object per line, so it can be read while playing. The file starts fresh
-- each time the game starts or CET reloads mods.

local INTERVAL = 0.25 -- seconds between lines
local MAX_PLAUSIBLE_SPEED = 100 -- m/s; GetVelocity() sometimes returns huge nonsense values

-- Locomotion values as the game's movement states write them (locomotionTransitions.script);
-- the decompiled gamePSMLocomotionStates enum is off by one from 4 on. 4 and 12 are unused.
local LOCOMOTION = {
    [0] = "Default",
    [1] = "Crouch",
    [2] = "Sprint",
    [3] = "Kerenzikov",
    [5] = "Jump",
    [6] = "Vault",
    [7] = "Dodge",
    [8] = "DodgeAir",
    [9] = "Workspot",
    [10] = "Slide",
    [11] = "SlideFall",
    [13] = "CrouchDodge",
}
-- gamePSMHighLevel
local HIGH_LEVEL = {
    [0] = "Default",
    [1] = "SceneTier1",
    [2] = "SceneTier2",
    [3] = "SceneTier3",
    [4] = "SceneTier4",
    [5] = "SceneTier5",
    [6] = "Swimming",
}

---@type file*?
local file = nil
local time = 0
local next_write = 0
---@type Vector4?
local last_pos = nil
local last_time = 0

---@param player PlayerPuppet
---@return integer locomotion, integer high_level
local function psm_state(player)
    local defs = GetAllBlackboardDefs().PlayerStateMachine
    local bb = Game.GetBlackboardSystem():GetLocalInstanced(player:GetEntityID(), defs)
    return bb:GetInt(defs.Locomotion), bb:GetInt(defs.HighLevel)
end

---@param names table<integer, string>
---@param value integer
---@return string
local function name_of(names, value)
    return names[value] or tostring(value)
end

---@param player PlayerPuppet
---@return string
local function line(player)
    local pos = player:GetWorldPosition()
    -- speed from the position change since the last line; reliable, unlike GetVelocity()
    local speed = 0
    if last_pos and time > last_time then
        local dx, dy, dz = pos.x - last_pos.x, pos.y - last_pos.y, pos.z - last_pos.z
        speed = math.sqrt(dx * dx + dy * dy + dz * dz) / (time - last_time)
    end
    last_pos, last_time = pos, time
    local vel = player:GetVelocity()
    local vel_json = "null"
    if math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z) <= MAX_PLAUSIBLE_SPEED then
        vel_json = string.format("[%.2f,%.2f,%.2f]", vel.x, vel.y, vel.z)
    end
    local ok, loco, high = pcall(psm_state, player)
    local loco_name, high_name = "?", "?"
    if ok then
        loco_name, high_name = name_of(LOCOMOTION, loco), name_of(HIGH_LEVEL, high)
    end
    return string.format(
        '{"t":%.2f,"pos":[%.2f,%.2f,%.2f],"speed":%.2f,"vel":%s,"yaw":%.1f,'
            .. '"locomotion":"%s","high_level":"%s"}\n',
        time,
        pos.x,
        pos.y,
        pos.z,
        speed,
        vel_json,
        player:GetWorldYaw(),
        loco_name,
        high_name
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
