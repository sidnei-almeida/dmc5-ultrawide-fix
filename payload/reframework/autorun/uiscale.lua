function logger(it)
    log.debug(it)
end

function vec3_tostring(vec)
    return tostring(vec.x) .. ", " .. tostring(vec.y) .. ", " .. tostring(vec.z)
end
function vec4_tostring(vec)
    return vec3_tostring(vec) .. ", " .. tostring(vec.w)
end

local gui_type = sdk.typeof("via.gui.GUI")

local x_scale = 1
local y_scale = 0.5

local x_scale_cutscenes = 1
local y_scale_cutscenes = 1

local x_offset = 0
local y_offset = 0

local x_offset_cutscenes = 0
local y_offset_cutscenes = 0

local disable = false
local filter_method = "allowlist"
local developer = false

local json_name = "uiscale.json"
local settings = json.load_file(json_name)
if(settings ~= nil) then
    x_scale = settings.x_scale
    y_scale = settings.y_scale

    x_offset = settings.x_offset
    y_offset = settings.y_offset

    disable = settings.disable == true

    local v111Settings = settings.v111Settings
    if v111Settings ~= nil then
        x_scale_cutscenes = v111Settings.x_scale_cutscenes
        y_scale_cutscenes = v111Settings.y_scale_cutscenes
        x_offset_cutscenes = v111Settings.x_offset_cutscenes
        y_offset_cutscenes = v111Settings.y_offset_cutscenes
        filter_method = v111Settings.filter_method
        developer = v111Settings.developer
    end
end

function save_settings()
    local all_settings = { 
        x_scale = x_scale,
        y_scale = y_scale,
        x_offset = x_offset,
        y_offset = y_offset,
        disable = disable,
        v111Settings = {
            x_scale_cutscenes = x_scale_cutscenes,
            y_scale_cutscenes = y_scale_cutscenes,
            x_offset_cutscenes = x_offset_cutscenes,
            y_offset_cutscenes = y_offset_cutscenes,
            filter_method = filter_method,
            developer = developer
        }
    }
    json.dump_file(json_name, all_settings)
end

re.on_draw_ui(function()
    if imgui.tree_node("UI Scale") then
        changed1, disable = imgui.checkbox(" disable", disable)
        changed2, x_scale = imgui.slider_float(" x-scale", x_scale, 0, 1)
        changed3, y_scale = imgui.slider_float(" y-scale", y_scale, 0, 1)
        changed4, x_scale_cutscenes = imgui.slider_float(" x-scale (loading screens)", x_scale_cutscenes, 0, 1)
        changed5, y_scale_cutscenes = imgui.slider_float(" y-scale (loading screens)", y_scale_cutscenes, 0, 1)
        changed6, x_offset = imgui.slider_float(" x-offset", x_offset, 0, 4000)
        changed7, y_offset = imgui.slider_float(" y_offset", y_offset, 0, 1000)
        changed8, x_offset_cutscenes = imgui.slider_float(" x-offset (loading screens)", x_offset_cutscenes, 0, 4000)
        changed9, y_offset_cutscenes = imgui.slider_float(" y_offset (loading screens)", y_offset_cutscenes, 0, 1000)
        changed10, filter_method = imgui.combo(" filter method", filter_method, { allowlist = "allowlist", blocklist = "blocklist" })
        changed11, developer = imgui.checkbox(" debug logging, reset filtered, ...", developer)

        if 
            changed1 or 
            changed2 or 
            changed3 or 
            changed4 or 
            changed5 or 
            changed6 or 
            changed7 or 
            changed8 or 
            changed9 or 
            changed10 or 
            changed11 then
            save_settings()
        end
    end
end)

local game_object_get_component = sdk.find_type_definition("via.GameObject"):get_method("getComponent(System.Type)")

function set_add(aset, value)
    aset[value] = true
end

function set_contains(aset, value)
    return aset[value] == true
end

local blocklist_name = {}
local blocklist_type = {}
set_add(blocklist_name, "SaveLoadIcon_GUImesh")
-- gauntlet overlay
set_add(blocklist_name, "pickupGauntletHud")
set_add(blocklist_name, "Fade_Loading")
set_add(blocklist_name, "Fade_InGame")
set_add(blocklist_name, "Fade_Menu")
-- secret mission marker
set_add(blocklist_name, "SecretVision")
-- shop messages
set_add(blocklist_name, "ui0002")
-- loading screen
set_add(blocklist_name, "ui0040")
set_add(blocklist_name, "ui0041")
set_add(blocklist_name, "ui3107")
set_add(blocklist_name, "ui3108_s10")
-- overlay: start secret mission
set_add(blocklist_name, "MessageLabel")
set_add(blocklist_name, "ui3104")
-- overlay: secret mission instructions
set_add(blocklist_name, "ui7002")
-- some boss names
set_add(blocklist_name, "ui2065")
set_add(blocklist_name, "m16_200_UI")
set_add(blocklist_name, "m17_300_UI")
set_add(blocklist_name, "m20_100_TitleUI")
-- credits
set_add(blocklist_name, "ui6000")
set_add(blocklist_name, "ScarsGUI")
set_add(blocklist_name, "ScarsRoughnessGUI")
set_add(blocklist_name, "ScarsNormalGUI")
set_add(blocklist_name, "Fade_Menu")
-- billboard in mission 2
set_add(blocklist_name, "ui9000")
-- nidhogg hatchling messages
set_add(blocklist_name, "ui3102")
set_add(blocklist_name, "ui3103")
-- next-objective effect
set_add(blocklist_name, "ui1025")
-- training hud
set_add(blocklist_name, "ui8013")

-- hp markers
table.insert(blocklist_type, sdk.typeof("app.ui1008GUI"))
-- target markers
table.insert(blocklist_type, sdk.typeof("app.ui1009GUI"))
table.insert(blocklist_type, sdk.typeof("app.ui1010GUI"))

local cutscene_name = {}
local cutscene_type = {}
-- intro
set_add(cutscene_name, "ui7004")
set_add(cutscene_name, "StartLogo")
set_add(cutscene_name, "ui2201_Vergil")
-- loading screens
set_add(cutscene_name, "ui3101")
set_add(cutscene_name, "ui3120")
set_add(cutscene_name, "ui8022")
--table.insert(cutscene_type, sdk.typeof("app.ui1007GUI"))

local right_aligned_names = {}
local right_aligned_types = {}
-- points (duh!)
set_add(right_aligned_names, "point_hud")
-- gauntlet UI
table.insert(right_aligned_types, sdk.typeof("app.ui1013GUI"))
-- c-c-combo
table.insert(right_aligned_types, sdk.typeof("app.ui1014GUI"))
-- ORBS
table.insert(right_aligned_types, sdk.typeof("app.ui1020GUI"))

local bot_aligned_types = {}
-- boss health
table.insert(bot_aligned_types, sdk.typeof("app.ui1007GUI"))
-- gauntlet UI
table.insert(bot_aligned_types, sdk.typeof("app.ui1013GUI"))

local centered_types = {}
-- boss health
table.insert(centered_types, sdk.typeof("app.ui1007GUI"))


local allowlist_name = {}
local allowlist_type = {}
-- add other overrides as default
for name,_ in pairs(cutscene_name) do
    set_add(allowlist_name, name)
end
-- add others
-- main menus
set_add(allowlist_name, "ui2032")
set_add(allowlist_name, "ui2003")
set_add(allowlist_name, "ui2046")
-- mission start menu
set_add(allowlist_name, "ui2004")
set_add(allowlist_name, "ui2120")
-- in game menu
set_add(allowlist_name, "ui3105")
set_add(allowlist_name, "ui3111")
-- in game shop
set_add(allowlist_name, "ui2027")
-- skill list
set_add(allowlist_name, "ui3110")
-- tutorial message
set_add(allowlist_name, "ui7001")
-- secret mission menu
set_add(allowlist_name, "ui8021")
-- initial load screen
set_add(allowlist_name, "BootLoad")
-- points (duh!)
set_add(allowlist_name, "point_hud")
-- training menu
set_add(allowlist_name, "ui8011")
-- result screen
set_add(allowlist_name, "ui3201")
set_add(allowlist_name, "ui3202")
set_add(allowlist_name, "ui3203")
-- options
set_add(allowlist_name, "ui4000")
-- game over
set_add(allowlist_name, "ui3007")
set_add(allowlist_name, "ui3008")
-- credits
set_add(allowlist_name, "m21_100_StaffUI")
set_add(allowlist_name, "ui7100Unroll")
set_add(allowlist_name, "ui7100DLC")
-- weapon change
table.insert(allowlist_type, sdk.typeof("app.ui1018GUI"))
table.insert(allowlist_type, sdk.typeof("app.ui1026GUI"))
-- c-c-combo
table.insert(allowlist_type, sdk.typeof("app.ui1014GUI"))
-- ORBS
table.insert(allowlist_type, sdk.typeof("app.ui1020GUI"))
-- boss health
table.insert(allowlist_type, sdk.typeof("app.ui1007GUI"))
-- gauntlet UI
table.insert(allowlist_type, sdk.typeof("app.ui1013GUI"))
-- devil trigger/HP
table.insert(allowlist_type, sdk.typeof("app.ui1015GUI"))
-- Vergil HP
table.insert(allowlist_type, sdk.typeof("app.ui1027GUI"))
-- Nero HP
table.insert(allowlist_type, sdk.typeof("app.ui1011GUI"))
-- V HP
table.insert(allowlist_type, sdk.typeof("app.ui1016GUI"))
-- time cutscene
table.insert(allowlist_type, sdk.typeof("app.EventTimeGUI"))


function has_type(list_of_types, game_object)
    for _, type in ipairs(list_of_types) do
        if game_object_get_component(game_object, type) ~= nil then
            return true
        end 
    end
    return false
end

function is_blocklisted(game_object, name)
    return set_contains(blocklist_name, name) or
        has_type(blocklist_type, game_object)
end

function is_allowlisted(game_object, name)
    return set_contains(allowlist_name, name) or
        has_type(allowlist_type, game_object)
end

function do_scale(game_object, name)
    if disable then
        return false
    end
    if filter_method == "allowlist" then
        return is_allowlisted(game_object, name)
    else
        return not is_blocklisted(game_object, name)
    end
end

function is_cutscene(game_object, name)
    return
        set_contains(cutscene_name, name) or
        has_type(cutscene_type, game_object)
end

function draw_right_aligned(game_object, name)
    return 
        set_contains(right_aligned_names, name) or 
        has_type(right_aligned_types, game_object)
end

function draw_bot_aligned(game_object, name)
    return has_type(bot_aligned_types, game_object)
end

function draw_centered(game_object, name)
    return has_type(centered_types, game_object)
end

re.on_pre_gui_draw_element(function(element, context)
    local game_object = (element:read_qword(0x10) ~= 0) and element:call("get_GameObject")
    if game_object ~= nil then 
        local transform = game_object:get_Transform()
        local position = transform:get_position()
        local name = game_object:get_Name()

        local should_scale = do_scale(game_object, name)

        if should_scale then
            if developer and filter_method == "blocklist" then
                logger(tostring(name))
            end

            local gui_component = game_object_get_component(game_object, gui_type)
            local view = gui_component:get_View()

            local x_s = x_scale
            local y_s = y_scale

            local x_off = x_offset
            local y_off = y_offset

            if is_cutscene(game_object, name) then
                x_s = x_scale_cutscenes
                y_s = y_scale_cutscenes
                x_off = x_offset_cutscenes
                y_off = y_offset_cutscenes
            end

            view:set_Scale(Vector3f.new(x_s, y_s, 1))
            if draw_right_aligned(game_object, name) then
                x_off = -x_off
            end
            if draw_bot_aligned(game_object, name) then
                y_off = -y_off
            end
            if draw_centered(game_object, name) then
                x_off = 0
            end
            view:set_Position(Vector3f.new(x_off, y_off, 0))
        end
        if developer and not should_scale then
            if filter_method == "allowlist" and not is_blocklisted(game_object, name) then
                logger(tostring(name))
            end
            local gui_component = game_object_get_component(game_object, gui_type)
            local view = gui_component:get_View()
            view:set_Scale(Vector3f.new(1, 1, 1))
            view:set_Position(Vector3f.new(0, 0, 0))
        end
    end
    return true
end)