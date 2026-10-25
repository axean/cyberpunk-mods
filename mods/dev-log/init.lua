-- dev-log (CET): writes V's movement and camera to dev_log.jsonl in this mod's folder, one JSON
-- object per line, so it can be read while playing. 4 lines per second, or every frame after
-- the "per-frame" hotkey. The "mark" hotkey writes a numbered marker line (e.g. before a test
-- move). If the parkour mod is installed, its state is logged too. The file starts fresh each
-- time the game starts or CET reloads mods.

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

-- The active camera's world transform. It's an out parameter in the game's API; CET may return
-- it or fill a passed Transform, so both are tried.
---@param cameras CameraSystem
---@return Transform?
local function camera_transform(cameras)
    local ok, first, second = pcall(cameras.GetActiveCameraWorldTransform, cameras)
    if ok and type(second) == "userdata" then
        return second
    elseif ok and type(first) == "userdata" then
        return first
    end
    local transform = Transform.new()
    if pcall(cameras.GetActiveCameraWorldTransform, cameras, transform) then
        return transform
    end
    return nil
end

-- Camera as JSON fields: camera position minus V's position, view pitch/yaw/roll in degrees
-- from the active camera's forward and right vectors, and FOV (as the game reports it).
---@param player PlayerPuppet
---@return string
local function camera_json(player)
    local cameras = Game.GetCameraSystem()
    local fwd, right = cameras:GetActiveCameraForward(), cameras:GetActiveCameraRight()
    local yaw = math.deg(math.atan2(fwd.y, fwd.x))
    local pitch = math.deg(math.asin(math.max(-1, math.min(1, fwd.z))))
    local roll = math.deg(math.asin(math.max(-1, math.min(1, -right.z))))
    local offset = "null"
    local transform = camera_transform(cameras)
    if transform then
        local cam, pos = transform.position, player:GetWorldPosition()
        offset = string.format("[%.3f,%.3f,%.3f]", cam.x - pos.x, cam.y - pos.y, cam.z - pos.z)
    end
    return string.format(
        '"cam_off":%s,"cam_rot":[%.2f,%.2f,%.2f],"fov":%.2f',
        offset,
        pitch,
        yaw,
        roll,
        cameras:GetActiveCameraFOV()
    )
end

---@class ParkourWallView
---@field dist number
---@field normal number[]

-- What dev-log reads from the parkour mod (its Parkour.state).
---@class ParkourStateView
---@field walls table<string, ParkourWallView>?
---@field mode string?
---@field side integer?
---@field time number?
---@field last_exit string?
---@field roll number?
---@field pitch number?
---@field momentum boolean?
---@field carry number?
---@field impact number?
---@field input number[]?
---@field sprint_button boolean?

-- The parkour mod's state, if it's installed: ',"parkour":{...}' or "".
---@return string
local function parkour_json()
    local ok, mod = pcall(GetMod, "parkour")
    ---@cast mod { state: ParkourStateView? }?
    if not ok or type(mod) ~= "table" or type(mod.state) ~= "table" then
        return ""
    end
    local state = mod.state --[[@as ParkourStateView]]
    ---@type string[]
    local walls = {}
    for _, key in ipairs({
        "left",
        "right",
        "left_high",
        "right_high",
        "ahead",
        "ahead_high",
        "ahead_top",
    }) do
        local hit = state.walls and state.walls[key]
        if hit then
            local n = hit.normal
            walls[#walls + 1] =
                string.format('"%s":[%.3f,%.3f,%.3f,%.3f]', key, hit.dist, n[1], n[2], n[3])
        end
    end
    return string.format(
        ',"parkour":{"mode":"%s","side":%d,"time":%.3f,"last_exit":"%s","roll":%.2f,"pitch":%.2f,'
            .. '"momentum":%s,"carry":%.2f,"impact":%.2f,"input":[%.2f,%.2f],"sprint_button":%s,'
            .. '"walls":{%s}}',
        state.mode or "",
        state.side or 0,
        state.time or 0,
        state.last_exit or "",
        state.roll or 0,
        state.pitch or 0,
        tostring(state.momentum == true),
        state.carry or 0,
        state.impact or 0,
        state.input and state.input[1] or 0,
        state.input and state.input[2] or 0,
        tostring(state.sprint_button == true),
        table.concat(walls, ",")
    )
end

-- V's movement stats as the game applies them now: ',"stats":[max speed, acceleration,
-- deceleration]' or "".
---@param player PlayerPuppet
---@return string
local function stats_json(player)
    local stats = Game.GetStatsSystem()
    local id = player:GetEntityID()
    local ok, max_speed, accel, decel = pcall(function()
        return stats:GetStatValue(id, gamedataStatType.MaxSpeed),
            stats:GetStatValue(id, gamedataStatType.Acceleration),
            stats:GetStatValue(id, gamedataStatType.Deceleration)
    end)
    if not ok then
        return ""
    end
    return string.format(',"stats":[%.2f,%.2f,%.2f]', max_speed, accel, decel)
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
            .. '"locomotion":"%s","high_level":"%s",%s%s%s}\n',
        time,
        vec3(pos),
        speed,
        speed_h,
        vel_json,
        player:GetWorldYaw(),
        loco_name,
        high_name,
        cam,
        stats_json(player),
        parkour_json()
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

registerForEvent("onInit", function()
    file = io.open("dev_log.jsonl", "w")
end)

registerHotkey("dev_log_per_frame", "dev-log: per-frame on/off", function()
    per_frame = not per_frame
    local text = "dev-log: per-frame " .. (per_frame and "on" or "off")
    print(text)
    pcall(notify, text)
end)

registerHotkey("dev_log_mark", "dev-log: mark", function()
    marks = marks + 1
    if file then
        file:write(string.format('{"t":%.3f,"mark":%d}\n', time, marks))
        file:flush()
    end
    print("dev-log: mark " .. marks)
    pcall(notify, "dev-log: mark " .. marks)
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
