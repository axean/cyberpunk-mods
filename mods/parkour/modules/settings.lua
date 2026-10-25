-- Tunable settings: each module registers its tuning table and the fields to expose; they show
-- as sliders in a "parkour" window in the CET overlay (one collapsible section per module, with
-- a reset button), change the table in place so the module uses them right away, and are saved
-- to settings.txt in the mod folder ("section.key=value" lines) and loaded on start.

local settings = {}

---@class Slider
---@field key string field in the values table
---@field label string
---@field min number
---@field max number
---@field format? string default "%.2f"
---@field values? table<string, any> the table holding key, if not the section's

---@class Section
---@field name string
---@field order number position in the window
---@field values table<string, any>
---@field sliders Slider[]
---@field defaults table<Slider, number>

---@type Section[]
local sections = {}

local FILE = "settings.txt"

---@param slider Slider
---@param section Section
---@return table<string, any>
local function target(slider, section)
    return slider.values or section.values
end

-- Register a module's tuning table; call when the module loads, before settings.load().
---@param name string section title in the window and prefix in the file
---@param order number position in the window
---@param values table<string, any>
---@param sliders Slider[]
function settings.section(name, order, values, sliders)
    ---@type Section
    local section =
        { name = name, order = order, values = values, sliders = sliders, defaults = {} }
    for _, slider in ipairs(sliders) do
        section.defaults[slider] = target(slider, section)[slider.key]
    end
    sections[#sections + 1] = section
    table.sort(sections, function(a, b)
        return a.order < b.order
    end)
end

-- Apply the saved values.
function settings.load()
    local file = io.open(FILE, "r")
    if not file then
        return
    end
    ---@type table<string, number>
    local saved = {}
    for line in file:lines() do
        ---@cast line string
        local eq = line:find("=", 1, true)
        if eq then
            local number = tonumber(line:sub(eq + 1))
            if number then
                saved[line:sub(1, eq - 1)] = number
            end
        end
    end
    file:close()
    for _, section in ipairs(sections) do
        for _, slider in ipairs(section.sliders) do
            local value = saved[section.name .. "." .. slider.key]
            if value then
                target(slider, section)[slider.key] = value
            end
        end
    end
end

local function save()
    local file = io.open(FILE, "w")
    if not file then
        return
    end
    for _, section in ipairs(sections) do
        for _, slider in ipairs(section.sliders) do
            local value = target(slider, section)[slider.key]
            file:write(string.format("%s.%s=%.4f\n", section.name, slider.key, value))
        end
    end
    file:close()
end

-- Draw the window; call from onDraw while the overlay is open.
function settings.draw()
    if ImGui.Begin("parkour") then
        local changed = false
        for _, section in ipairs(sections) do
            if ImGui.CollapsingHeader(section.name) then
                for _, slider in ipairs(section.sliders) do
                    local values = target(slider, section)
                    local value, used = ImGui.SliderFloat(
                        slider.label .. "##" .. section.name,
                        values[slider.key],
                        slider.min,
                        slider.max,
                        slider.format or "%.2f"
                    )
                    if used then
                        values[slider.key], changed = value, true
                    end
                end
                if ImGui.Button("reset " .. section.name) then
                    for _, slider in ipairs(section.sliders) do
                        target(slider, section)[slider.key] = section.defaults[slider]
                    end
                    changed = true
                end
            end
        end
        if changed then
            save()
        end
    end
    ImGui.End()
end

return settings
