-- dev-log (CET): writes V's movement and camera to dev_log.jsonl in this mod's folder, one JSON
-- object per line, so it can be read while playing. 4 lines per second, or every frame after
-- the "per-frame" hotkey. The "mark" hotkey writes a numbered marker line (e.g. before a test
-- move). The file starts fresh each time the game starts or CET reloads mods.

local INTERVAL = 0.25 -- seconds between lines, unless per-frame
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
local per_frame = false
local marks = 0
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

---@param v Vector4
---@return string
local function vec3(v)
    return string.format("[%.3f,%.3f,%.3f]", v.x, v.y, v.z)
end

-- Camera as JSON fields: offset of the first-person camera from V (local), view yaw/pitch/roll
-- in degrees from the active camera's forward and right vectors, and FOV.
---@param player PlayerPuppet
---@return string
local function camera_json(player)
    local cameras = Game.GetCameraSystem()
    local fwd, right = cameras:GetActiveCameraForward(), cameras:GetActiveCameraRight()
    local yaw = math.deg(math.atan2(fwd.y, fwd.x))
    local pitch = math.deg(math.asin(math.max(-1, math.min(1, fwd.z))))
    local roll = math.deg(math.asin(math.max(-1, math.min(1, -right.z))))
    return string.format(
        '"cam_local":%s,"cam_rot":[%.2f,%.2f,%.2f],"fov":%.2f',
        vec3(player:GetFPPCameraComponent():GetLocalPosition()),
        pitch,
        yaw,
        roll,
        cameras:GetActiveCameraFOV()
    )
end

---@param player PlayerPuppet
---@return string
local function line(player)
    local pos = player:GetWorldPosition()
    -- speed from the position change since the last line; reliable, unlike GetVelocity()
    local speed, speed_h = 0, 0
    if last_pos and time > last_time then
        local dx, dy, dz = pos.x - last_pos.x, pos.y - last_pos.y, pos.z - last_pos.z
        speed = math.sqrt(dx * dx + dy * dy + dz * dz) / (time - last_time)
        speed_h = math.sqrt(dx * dx + dy * dy) / (time - last_time)
    end
    last_pos, last_time = pos, time
    local vel = player:GetVelocity()
    local vel_json = "null"
    if math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z) <= MAX_PLAUSIBLE_SPEED then
        vel_json = vec3(vel)
    end
    local ok, loco, high = pcall(psm_state, player)
    local loco_name, high_name = "?", "?"
    if ok then
        loco_name, high_name = name_of(LOCOMOTION, loco), name_of(HIGH_LEVEL, high)
    end
    local cam_ok, cam = pcall(camera_json, player)
    if not cam_ok then
        cam = '"cam_error":true'
    end
    return string.format(
        '{"t":%.3f,"pos":%s,"speed":%.2f,"speed_h":%.2f,"vel":%s,"yaw":%.1f,'
            .. '"locomotion":"%s","high_level":"%s",%s}\n',
        time,
        vec3(pos),
        speed,
        speed_h,
        vel_json,
        player:GetWorldYaw(),
        loco_name,
        high_name,
        cam
    )
end

registerForEvent("onInit", function()
    file = io.open("dev_log.jsonl", "w")
end)

registerHotkey("dev_log_per_frame", "dev-log: per-frame on/off", function()
    per_frame = not per_frame
    print("dev-log: per-frame " .. (per_frame and "on" or "off"))
end)

registerHotkey("dev_log_mark", "dev-log: mark", function()
    marks = marks + 1
    if file then
        file:write(string.format('{"t":%.3f,"mark":%d}\n', time, marks))
        file:flush()
    end
    print("dev-log: mark " .. marks)
end)

---@param delta number
registerForEvent("onUpdate", function(delta)
    time = time + delta
    if not file or (not per_frame and time < next_write) then
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
