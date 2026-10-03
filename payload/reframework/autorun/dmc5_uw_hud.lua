-- dmc5_uw_hud.lua
-- Keeps DMC5's HUD/menus inside the screen when REFramework's Ultrawide fix is on.
-- REFramework's own "Constrain UI" only touches views of type Screen; DMC5's HUD
-- views are not, so they get scaled by the width ratio and overflow. This forces
-- every via.gui.View to scale by the smaller axis and anchor at the center, which
-- gives the vanilla 16:9 layout centered on the ultrawide screen.

local cfg_name = "dmc5_uw_hud.json"
local cfg = json.load_file(cfg_name) or {}
local enabled = cfg.enabled ~= false
local debug_log = cfg.debug_log == true

local function save_cfg()
    json.dump_file(cfg_name, { enabled = enabled, debug_log = debug_log })
end

local function enum_value(type_name, field_name)
    local t = sdk.find_type_definition(type_name)
    if t == nil then return nil end
    local f = t:get_field(field_name)
    if f == nil then return nil end
    return f:get_data(nil)
end

local FIT_SMALL = enum_value("via.gui.ResolutionAdjustScale", "FitSmallRatioAxis")
local CENTER = enum_value("via.gui.ResolutionAdjustAnchor", "CenterCenter")

local FIT_LARGE = enum_value("via.gui.ResolutionAdjustScale", "FitLargeRatioAxis")

local function dump_enum(type_name)
    local t = sdk.find_type_definition(type_name)
    if t == nil then return end
    local parts = {}
    for _, f in ipairs(t:get_fields()) do
        if f:is_static() then
            local ok, v = pcall(function() return f:get_data(nil) end)
            if ok then table.insert(parts, f:get_name() .. "=" .. tostring(v)) end
        end
    end
    log.info("[dmc5_uw_hud] " .. type_name .. ": " .. table.concat(parts, " "))
end
dump_enum("via.gui.ResolutionAdjustScale")
dump_enum("via.gui.ResolutionAdjustAnchor")
dump_enum("via.gui.ViewType")

log.info(string.format("[dmc5_uw_hud] enabled=%s FitSmallRatioAxis=%s FitLargeRatioAxis=%s CenterCenter=%s",
    tostring(enabled), tostring(FIT_SMALL), tostring(FIT_LARGE), tostring(CENTER)))

-- Full-screen overlays (fades, cutscene/letterbox GUIs, loading screens).
-- Forcing a resolution-adjust mode on these breaks their placement (a fade
-- quad ends up covering only the top half of the screen), so leave them alone.
local skip_patterns = { "^Fade_", "^BlackFade", "^ClipPlayGUI", "^IntroductionGUI", "[Ll]etter[Bb]ox", "^ui0040", "^ui0041", "^ui3101", "^ui3107", "^ui3108", "^ui3120", "^BootLoad", "^StartLogo", "^SaveLoadIcon" }

local dumped = {}
local function dump_tree(e, depth, out)
    if e == nil or depth > 5 or #out > 80 then return end
    local ok, line = pcall(function()
        local tn = e:get_type_definition():get_full_name()
        local nm = tostring(e:call("get_Name"))
        local pos = ""
        local okp, p = pcall(function() return e:call("get_Position") end)
        if okp and p ~= nil then pos = string.format(" pos=(%.0f,%.0f)", p.x, p.y) end
        local sz = ""
        local oks, sv = pcall(function() return e:call("get_Size") end)
        if oks and sv ~= nil then
            local okw, w = pcall(function() return sv.w or sv.x end)
            local okh, h = pcall(function() return sv.h or sv.y end)
            if okw and okh and w and h then sz = string.format(" size=(%.0f,%.0f)", w, h) end
        end
        local vis = ""
        local okv, v = pcall(function() return e:call("get_Visible") end)
        if okv and v ~= nil then vis = " vis=" .. tostring(v) end
        return string.rep("  ", depth) .. tn .. " '" .. nm .. "'" .. pos .. sz .. vis
    end)
    table.insert(out, ok and line or (string.rep("  ", depth) .. "<err " .. tostring(line) .. ">"))
    local okc, child = pcall(function() return e:call("get_Child") end)
    if okc and child ~= nil then dump_tree(child, depth + 1, out) end
    local okn, nxt = pcall(function() return e:call("get_Next") end)
    if okn and nxt ~= nil then dump_tree(nxt, depth, out) end
end

local function wants_skip(name)
    for _, pat in ipairs(skip_patterns) do
        if string.find(name, pat) then return true end
    end
    return false
end

local seen = {}

re.on_pre_gui_draw_element(function(element, context)
    if not enabled or FIT_SMALL == nil or CENTER == nil then return true end
    if element:read_qword(0x10) == 0 then return true end

    local go = element:call("get_GameObject")
    if go == nil then return true end
    local name = go:call("get_Name")
    if name == "BlackFade" then return true end

    local view = element:call("get_View")
    if view == nil then return true end

    if debug_log and not seen[name] then
        seen[name] = true
        local ok, msg = pcall(function()
            return string.format("[dmc5_uw_hud] %s viewtype=%s adjust=%s scale=%s anchor=%s",
                tostring(name),
                tostring(view:call("get_ViewType")),
                tostring(view:call("get_ResolutionAdjust")),
                tostring(view:call("get_ResAdjustScale")),
                tostring(view:call("get_ResAdjustAnchor")))
        end)
        log.info(ok and msg or ("[dmc5_uw_hud] log error: " .. tostring(msg)))
    end

    if wants_skip(name) then
        if debug_log and not dumped[name] and string.find(name, "^Fade_") then
            dumped[name] = true
            local out = {}
            dump_tree(view, 0, out)
            log.info("[dmc5_uw_hud] tree of " .. name .. ":\n" .. table.concat(out, "\n"))
        end
        return true
    end

    local mode = FIT_SMALL

    view:call("set_ResAdjustScale", mode)
    view:call("set_ResAdjustAnchor", CENTER)
    view:call("set_ResolutionAdjust", true)

    local child = view:call("get_Child")
    if child ~= nil then
        child:call("set_ResAdjustScale", mode)
        child:call("set_ResAdjustAnchor", CENTER)
        child:call("set_ResolutionAdjust", true)
    end
    return true
end)

re.on_draw_ui(function()
    if imgui.tree_node("DMC5 Ultrawide HUD") then
        local c1, c2
        c1, enabled = imgui.checkbox("Keep HUD/menus in 16:9 area", enabled)
        c2, debug_log = imgui.checkbox("Log GUI elements to re2_framework_log.txt", debug_log)
        if c1 or c2 then save_cfg() end
        imgui.tree_pop()
    end
end)
