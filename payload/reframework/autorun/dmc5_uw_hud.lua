-- dmc5_uw_hud.lua
-- Keeps DMC5's HUD and menus at their 16:9 size on ultrawide screens.
--
-- With REFramework's Ultrawide fix on, DMC5 draws HUD/menus through
-- via.gui views of type World. Their 1920x1080 canvas is scaled by the
-- *width* ratio (3440/1920 = 1.79x on 21:9) and centred vertically, so the
-- health bar leaves through the top and the Devil Breakers through the
-- bottom. Resolution-adjust settings do nothing on World views, so this
-- script rescales the view itself by (16/9) / (screen aspect), which brings
-- every element back to the size it has at 16:9. Offsets are exposed for
-- people who want the HUD pushed to the screen edges or towards the centre.

local cfg_name = "dmc5_uw_hud.json"
local cfg = json.load_file(cfg_name) or {}
local enabled = cfg.enabled ~= false
local debug_log = cfg.debug_log == true
local scale_override = tonumber(cfg.scale_override) or 0 -- 0 = automatic
local x_offset = tonumber(cfg.x_offset) or 0
local y_offset = tonumber(cfg.y_offset) or 0
local center = cfg.center ~= false -- put the 16:9 canvas in the middle of the screen
local hud3d_enabled = cfg.hud3d_enabled ~= false
local hud3d_scale_override = tonumber(cfg.hud3d_scale_override) or 0 -- 0 = automatic
local hud3d_x_factor = tonumber(cfg.hud3d_x_factor) or 1.0 -- extra multiplier on x
local hud3d_y_factor = tonumber(cfg.hud3d_y_factor) or 1.0 -- extra multiplier on y

local function save_cfg()
    json.dump_file(cfg_name, {
        enabled = enabled, debug_log = debug_log,
        scale_override = scale_override, x_offset = x_offset, y_offset = y_offset,
        center = center,
        hud3d_enabled = hud3d_enabled, hud3d_scale_override = hud3d_scale_override,
        hud3d_x_factor = hud3d_x_factor, hud3d_y_factor = hud3d_y_factor,
    })
end

-- Full-screen overlays that must not be touched.
local skip_patterns = { "^pickupGauntletHud", "^SecretVision", "^Fade_", "^BlackFade", "^ClipPlayGUI", "^IntroductionGUI", "[Ll]etter[Bb]ox",
    "^ui0040", "^ui0041", "^ui3101", "^ui3107", "^ui3108", "^ui3120", "^BootLoad", "^StartLogo", "^SaveLoadIcon" }
local function wants_skip(name)
    for _, pat in ipairs(skip_patterns) do
        if string.find(name, pat) then return true end
    end
    return false
end

local VIEWTYPE_WORLD = 1

local function auto_scale()
    local ds = imgui.get_display_size()
    if ds == nil or ds.x == nil or ds.y == nil or ds.y == 0 then return 1.0 end
    local s = (16.0 / 9.0) / (ds.x / ds.y)
    if s > 1.0 then s = 1.0 end -- narrower than 16:9: nothing to shrink
    return s
end

-- World views scale about their top-left origin, so after shrinking the
-- canvas sits at the left edge. Shift it right by half the leftover width.
-- Position is in canvas units (1920 wide), not screen pixels.
local function auto_x_center()
    local ds = imgui.get_display_size()
    if ds == nil or ds.x == nil or ds.y == nil or ds.x == 0 then return 0 end
    local leftover_px = ds.x - ds.y * (16.0 / 9.0)
    if leftover_px <= 0 then return 0 end
    return (leftover_px / 2.0) / (ds.x / 1920.0)
end

-- The 1920x1080 canvas is first blown up by the width ratio and centred
-- vertically, so its origin sits above the screen by half the overflow.
-- After shrinking it back we move it down by that amount (canvas units).
local function auto_y_center()
    local ds = imgui.get_display_size()
    if ds == nil or ds.x == nil or ds.y == nil or ds.x == 0 then return 0 end
    local width_ratio = ds.x / 1920.0
    local visible_canvas_h = ds.y / width_ratio
    local overflow = 1080.0 - visible_canvas_h
    if overflow <= 0 then return 0 end
    return overflow / 2.0
end

local function effective_offsets()
    local x, y = x_offset, y_offset
    if center then
        x = x + auto_x_center()
        y = y + auto_y_center()
    end
    return x, y
end

local function current_scale()
    if scale_override > 0 then return scale_override end
    return auto_scale()
end

log.info(string.format("[dmc5_uw_hud] enabled=%s auto_scale=%.4f x_offset=%.1f y_offset=%.1f",
    tostring(enabled), auto_scale(), x_offset, y_offset))

local seen = {}

-- GUIs that project 3D positions onto the screen (lock-on reticle, enemy
-- markers, pickups): scaling their view moves the marker off the target.
local skip_types = {}
for _, tn in ipairs({ "app.ui1008GUI", "app.ui1009GUI", "app.ui1010GUI" }) do
    local ok, t = pcall(sdk.typeof, tn)
    if ok and t ~= nil then table.insert(skip_types, t) end
end
local get_component = sdk.find_type_definition("via.GameObject"):get_method("getComponent(System.Type)")
local function has_skip_type(go)
    for _, t in ipairs(skip_types) do
        local ok, c = pcall(function() return get_component:call(go, t) end)
        if ok and c ~= nil then return true end
    end
    return false
end

-- Root control names (the .gui asset name) of HUD parts that project 3D
-- positions on screen: lock-on reticle, enemy markers, item pickups.
local skip_control_patterns = { "^c_target", "^ui1008", "^ui1009", "^ui1010", "[Ll]ock[Oo]n", "[Mm]arker", "[Rr]eticle" }

local function root_control_name(view)
    local ok, child = pcall(function() return view:call("get_Child") end)
    if not ok or child == nil then return "" end
    local ok2, nm = pcall(function() return child:call("get_Name") end)
    return (ok2 and nm) and tostring(nm) or ""
end

local function wants_skip_control(ctrl)
    for _, pat in ipairs(skip_control_patterns) do
        if string.find(ctrl, pat) then return true end
    end
    return false
end

local function dump_tree(e, depth, out)
    if e == nil or depth > 3 or #out > 160 then return end
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
        local extra = ""
        for _, mname in ipairs({ "get_Scale", "get_Anchor", "get_HorizontalAnchor", "get_VerticalAnchor", "get_Alignment", "get_Pivot", "get_ScreenAnchor", "get_AdjustType" }) do
            local okx, xv = pcall(function() return e:call(mname) end)
            if okx and xv ~= nil then
                if type(xv) == "userdata" and xv.x ~= nil then extra = extra .. string.format(" %s=(%.2f,%.2f)", mname:sub(5), xv.x, xv.y)
                else extra = extra .. " " .. mname:sub(5) .. "=" .. tostring(xv) end
            end
        end
        return string.rep("  ", depth) .. tn .. " '" .. nm .. "'" .. pos .. sz .. vis .. extra
    end)
    table.insert(out, ok and line or (string.rep("  ", depth) .. "<err " .. tostring(line) .. ">"))
    local okc, child = pcall(function() return e:call("get_Child") end)
    if okc and child ~= nil then dump_tree(child, depth + 1, out) end
    local okn, nxt = pcall(function() return e:call("get_Next") end)
    if okn and nxt ~= nil then dump_tree(nxt, depth, out) end
end

local scene_seen = {}
local function apply_to_view(view, go, name, source)
    local viewtype = view:call("get_ViewType")
    local ctrl = root_control_name(view)
    if debug_log then
        local key = source .. "|" .. name .. "|" .. ctrl
        if not scene_seen[key] then
            scene_seen[key] = true
            local ok, msg = pcall(function()
                local p = view:call("get_Position")
                local sc = view:call("get_Scale")
                local ss = nil
                pcall(function() ss = view:call("get_ScreenSize") end)
                return string.format("[dmc5_uw_hud] %s: %s ctrl=%s viewtype=%s adjust=%s pos=(%.1f,%.1f) scale=(%.3f,%.3f) screen=(%s,%s)",
                    source, tostring(name), ctrl, tostring(viewtype), tostring(view:call("get_ResolutionAdjust")),
                    p and p.x or -1, p and p.y or -1, sc and sc.x or -1, sc and sc.y or -1,
                    tostring(ss and (ss.w or ss.x)), tostring(ss and (ss.h or ss.y)))
            end)
            log.info(ok and msg or ("[dmc5_uw_hud] log error: " .. tostring(msg)))
        end
    end
    if viewtype ~= VIEWTYPE_WORLD or wants_skip(name) or wants_skip_control(ctrl) then return end
    -- a game object that is only a 3D marker (not the shared HUD root) is skipped as a whole
    if name ~= "c_pos" and has_skip_type(go) then return end
    local s = current_scale()
    if s < 0.999 then
        view:call("set_Scale", Vector3f.new(s, s, 1.0))
    end
    -- HUD parts inside c_pos anchor to screen edges on their own; moving the
    -- whole view pushes the right/bottom ones off screen. Offsets are for menus.
    if name ~= "c_pos" then
        local ox, oy = effective_offsets()
        if ox ~= 0 or oy ~= 0 then
            view:call("set_Position", Vector3f.new(ox, oy, 0.0))
        end
    else
        view:call("set_Position", Vector3f.new(0.0, 0.0, 0.0))
    end
    if debug_log and name == "c_pos" and not scene_seen["tree|" .. ctrl] then
        scene_seen["tree|" .. ctrl] = true
        local out = {}
        dump_tree(view, 0, out)
        log.info("[dmc5_uw_hud] tree of c_pos/" .. ctrl .. ":\n" .. table.concat(out, "\n"))
    end
end

-- Periodic scene scan: DMC5's gameplay HUD (health, Devil Breakers, style
-- rank) never reaches REFramework's gui-draw hook, so we look the GUI
-- components up in the scene instead.
local gui_typeof = sdk.typeof("via.gui.GUI")
local scene_manager = sdk.get_native_singleton("via.SceneManager")
local scene_manager_t = sdk.find_type_definition("via.SceneManager")
local frame_counter = 0
local SCAN_EVERY = 30

local scenes_logged = {}
local function scan_one_scene(scene, label)
    local comps = scene:call("findComponents(System.Type)", gui_typeof)
    if comps == nil then return 0 end
    local list = comps:get_elements()
    if list == nil then return 0 end
    for _, comp in ipairs(list) do
        pcall(function()
            local go = comp:call("get_GameObject")
            if go == nil then return end
            local name = go:call("get_Name")
            if name == nil then return end
            local view = comp:call("get_View")
            if view == nil then return end
            apply_to_view(view, go, name, "scene[" .. label .. "]")
        end)
    end
    return #list
end

local function scan_scene()
    if scene_manager == nil or scene_manager_t == nil or gui_typeof == nil then return end
    -- every loaded scene, not just the current one: the player HUD lives in its own
    local scenes = sdk.call_native_func(scene_manager, scene_manager_t, "get_Scenes")
    local any = false
    if scenes ~= nil then
        local ok, list = pcall(function() return scenes:get_elements() end)
        if ok and list ~= nil then
            for i, scene in ipairs(list) do
                any = true
                local okn, sname = pcall(function() return scene:call("get_Name") end)
                local label = tostring(okn and sname or i)
                local n = scan_one_scene(scene, label)
                if debug_log and not scenes_logged[label] then
                    scenes_logged[label] = true
                    log.info(string.format("[dmc5_uw_hud] scene '%s': %d via.gui.GUI components", label, n))
                end
            end
        end
    end
    if not any then
        local scene = sdk.call_native_func(scene_manager, scene_manager_t, "get_CurrentScene")
        if scene ~= nil then scan_one_scene(scene, "current") end
    end
end

re.on_frame(function()
    if not enabled then return end
    frame_counter = frame_counter + 1
    if frame_counter % SCAN_EVERY ~= 0 then return end
    local ok, err = pcall(scan_scene)
    if not ok and debug_log then log.info("[dmc5_uw_hud] scan error: " .. tostring(err)) end
end)

local nogo_seen = {}
local function log_nogo(element, why)
    if not debug_log then return end
    local ok, tn = pcall(function() return element:get_type_definition():get_full_name() end)
    local key = tostring(ok and tn or "?") .. "|" .. why
    if nogo_seen[key] then return end
    nogo_seen[key] = true
    log.info("[dmc5_uw_hud] element without game object (" .. why .. "): " .. key)
end

re.on_pre_gui_draw_element(function(element, context)
    if not enabled then return true end
    if element:read_qword(0x10) == 0 then log_nogo(element, "qword0x10=0"); return true end

    local go = element:call("get_GameObject")
    if go == nil then log_nogo(element, "get_GameObject=nil"); return true end
    local name = go:call("get_Name")
    if name == nil then log_nogo(element, "name=nil"); return true end

    local view = element:call("get_View")
    if view == nil then return true end

    local viewtype = view:call("get_ViewType")

    if debug_log then
        local key = name .. "|" .. tostring(element:get_type_definition():get_full_name())
        if not seen[key] then
            seen[key] = true
            local ok, msg = pcall(function()
                local p = view:call("get_Position")
                local sc = view:call("get_Scale")
                return string.format("[dmc5_uw_hud] %s comp=%s viewtype=%s adjust=%s resscale=%s anchor=%s pos=(%.1f,%.1f) scale=(%.3f,%.3f)",
                    tostring(name), tostring(element:get_type_definition():get_full_name()),
                    tostring(viewtype), tostring(view:call("get_ResolutionAdjust")),
                    tostring(view:call("get_ResAdjustScale")), tostring(view:call("get_ResAdjustAnchor")),
                    p and p.x or -1, p and p.y or -1, sc and sc.x or -1, sc and sc.y or -1)
            end)
            log.info(ok and msg or ("[dmc5_uw_hud] log error: " .. tostring(msg)))
        end
    end

    apply_to_view(view, go, name, "hook")
    return true
end)

-- ---------------------------------------------------------------------------
-- 3D HUD (health / EX / DT gauge, Devil Breakers). DMC5 draws these as
-- via.gui.GUIMesh objects parked ~34 units in front of a camera, grouped
-- under a per-character root ("pl0000Hud" for Nero, ...). Scaling each
-- group by (k, k, 1) shrinks the meshes and pulls them towards the screen
-- centre without changing their depth, whatever projection draws them.
-- Runs right before rendering so it wins over the game's own timelines.
-- ---------------------------------------------------------------------------
local hud3d_roots = {}      -- name -> transform
local hud3d_last_scan = -1000
local hud3d_logged = {}

local function hud3d_scale()
    if hud3d_scale_override > 0 then return hud3d_scale_override end
    return auto_scale()
end

local function is_hud_root_name(nm)
    return nm:match("^pl%d%d%d%dHud$") ~= nil or nm:match("Hud$") ~= nil and nm:match("^pl") ~= nil
end

local function hud3d_find_roots()
    hud3d_roots = {}
    if scene_manager == nil or scene_manager_t == nil then return end
    local scene = sdk.call_native_func(scene_manager, scene_manager_t, "get_CurrentScene")
    if scene == nil then return end
    local ok, t = pcall(function() return scene:call("get_FirstTransform") end)
    if not ok then return end
    local guard = 0
    while t ~= nil and guard < 5000 do
        guard = guard + 1
        pcall(function()
            local go = t:call("get_GameObject")
            local nm = go and go:call("get_Name")
            if nm and is_hud_root_name(nm) then hud3d_roots[nm] = t end
        end)
        local okn, nxt = pcall(function() return t:call("get_Next") end)
        t = okn and nxt or nil
    end
end

local function hud3d_apply()
    local k = hud3d_scale()
    if k >= 0.999 and hud3d_x_factor == 1.0 and hud3d_y_factor == 1.0 then return end
    local sx, sy = k * hud3d_x_factor, k * hud3d_y_factor
    for root_name, root in pairs(hud3d_roots) do
        local okc, child = pcall(function() return root:call("get_Child") end)
        local guard = 0
        while okc and child ~= nil and guard < 64 do
            guard = guard + 1
            pcall(function()
                local go = child:call("get_GameObject")
                local nm = go and tostring(go:call("get_Name")) or "?"
                -- only the mesh groups; managers and 2D GUIs keep their scale
                if nm:match("GUImesh$") or nm:match("GUIMesh$") then
                    child:call("set_LocalScale", Vector3f.new(sx, sy, 1.0))
                    if debug_log and not hud3d_logged[root_name .. "/" .. nm] then
                        hud3d_logged[root_name .. "/" .. nm] = true
                        log.info(string.format("[dmc5_uw_hud] 3D HUD group %s/%s scaled to (%.3f,%.3f,1)", root_name, nm, sx, sy))
                    end
                end
            end)
            local okn, nxt = pcall(function() return child:call("get_Next") end)
            child = okn and nxt or nil
        end
    end
end

local function hud3d_restore()
    for _, root in pairs(hud3d_roots) do
        local okc, child = pcall(function() return root:call("get_Child") end)
        local guard = 0
        while okc and child ~= nil and guard < 64 do
            guard = guard + 1
            pcall(function()
                local go = child:call("get_GameObject")
                local nm = go and tostring(go:call("get_Name")) or "?"
                if nm:match("GUImesh$") or nm:match("GUIMesh$") then
                    child:call("set_LocalScale", Vector3f.new(1.0, 1.0, 1.0))
                end
            end)
            local okn, nxt = pcall(function() return child:call("get_Next") end)
            child = okn and nxt or nil
        end
    end
end

local hud3d_frame = 0
re.on_pre_application_entry("BeginRendering", function()
    if not enabled or not hud3d_enabled then return end
    hud3d_frame = hud3d_frame + 1
    if hud3d_frame - hud3d_last_scan >= 120 then
        hud3d_last_scan = hud3d_frame
        pcall(hud3d_find_roots)
        if debug_log then
            local names = {}
            for nm, _ in pairs(hud3d_roots) do table.insert(names, nm) end
            local key = table.concat(names, ",")
            if not hud3d_logged["roots|" .. key] then
                hud3d_logged["roots|" .. key] = true
                log.info("[dmc5_uw_hud] 3D HUD roots: " .. (key ~= "" and key or "(none)"))
            end
        end
    end
    pcall(hud3d_apply)
end)

re.on_draw_ui(function()
    if imgui.tree_node("DMC5 Ultrawide HUD") then
        local c1, c2, c3, c4, c5
        c1, enabled = imgui.checkbox("Rescale HUD/menus to 16:9 size", enabled)
        imgui.text(string.format("automatic scale for this screen: %.3f", auto_scale()))
        c2, scale_override = imgui.slider_float("scale override (0 = automatic)", scale_override, 0.0, 1.5)
        local c6
        c6, center = imgui.checkbox("Center the 16:9 canvas", center)
        imgui.text(string.format("automatic offset: x=%.1f y=%.1f canvas units", auto_x_center(), auto_y_center()))
        c3, x_offset = imgui.slider_float("extra x offset", x_offset, -2000.0, 2000.0)
        c4, y_offset = imgui.slider_float("extra y offset", y_offset, -1000.0, 1000.0)
        c5, debug_log = imgui.checkbox("Log GUI elements to re2_framework_log.txt", debug_log)
        imgui.separator()
        imgui.text("3D HUD (health gauge, Devil Breakers)")
        local c7, c8, c9, c10
        c7, hud3d_enabled = imgui.checkbox("Rescale 3D HUD", hud3d_enabled)
        if c7 and not hud3d_enabled then pcall(hud3d_restore) end
        c8, hud3d_scale_override = imgui.slider_float("3D scale override (0 = automatic)", hud3d_scale_override, 0.0, 1.5)
        c9, hud3d_x_factor = imgui.slider_float("3D x factor", hud3d_x_factor, 0.25, 2.0)
        c10, hud3d_y_factor = imgui.slider_float("3D y factor", hud3d_y_factor, 0.25, 2.0)
        if c1 or c2 or c3 or c4 or c5 or c6 or c7 or c8 or c9 or c10 then save_cfg() end
        imgui.tree_pop()
    end
end)
