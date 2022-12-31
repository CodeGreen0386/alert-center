local glib = require("__glib__/gui")
local e = defines.events
local handlers = {}
local defs = {}

---@param player LuaPlayer
local function create_gui(player)
    global.players[player.index] = {
        player = player,
        groups = {
            turret_fire = {},
            entity_under_attack = {},
            entity_destroyed = {},
        },
        alerts = {
            turret_fire = {},
            entity_under_attack = {},
            entity_destroyed = {},
        },
    }
    local refs = global.players[player.index]
    local _, gui = glib.add(player.gui.screen, defs.alert_gui, refs)
    return gui
end

---@param player LuaPlayer
local function setup_player(player)
    local gui = create_gui(player)
    gui.visible = false
end

local function initial_setup()
    global.players = {}
    for _, player in pairs(game.players) do
        setup_player(player)
    end
end

script.on_init(initial_setup)

local function open_gui(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local gui = player.gui.screen.alert_center
    if not gui then gui = create_gui(player) end
    gui.visible = true
    gui.force_auto_center()
    gui.bring_to_front()
end

script.on_event("alert-center", open_gui)
script.on_event(defines.events.on_lua_shortcut, function (event)
    if event.prototype_name ~= "alert-center" then return end
    open_gui(event)
end)

script.on_event(defines.events.on_player_created, function(event)
    setup_player(game.get_player(event.player_index) --[[@as LuaPlayer]])
end)

local vec = {}
function vec.new(n) return {x = n, y = n} end
function vec.mag(a) return math.sqrt(a.x^2 + a.y^2) end
function vec.add(a, b) return {x = a.x + b.x, y = a.y + b.y} end
function vec.sub(a, b) return {x = a.x - b.x, y = a.y - b.y} end
function vec.div(a, b) return {x = a.x / b.x, y = a.y / b.y} end

local function format_time(n)
    local s = math.floor(n / 60)
    local m = math.floor(s / 60)
    s = s % 60
    return string.format("%d:%02d", m, s)
end

local function alert_caption(count, time)
    return {"", {"alert-caption.count", count}, " (", format_time(time), ")"}
end

---@param player LuaPlayer
---@param name string
local function update_alerts(player, name)
    local alert_type = defines.alert_type[name]
    local polled_alerts = player.get_alerts{surface = player.surface, type = alert_type}
    if not next(polled_alerts) then return end
    local new_alerts = polled_alerts[player.surface.index][alert_type]
    local refs = global.players[player.index]
    local alerts = refs.alerts[name]
    local groups = refs.groups[name]
    local game_tick = game.tick
    for _, new_alert in pairs(new_alerts) do
        local position = new_alert.position or new_alert.target.position
        local id = position.x..","..position.y
        if alerts[id] then goto continue end
        local alert = {count = 0}
        alerts[id] = alert
        for group_id, group in pairs(groups) do
            local dist = vec.mag(vec.sub(group.position, position))
            if dist <= 20 then
                group.count = group.count + 1
                alert.group = group_id
                group.position = vec.add(vec.div(vec.sub(position, group.position), vec.new(group.count)), group.position)
                group.tick = game_tick
                goto continue
            end
        end
        local group = {count = 1, position = position, tick = game_tick} ---@type table<string,any>
        groups[id] = group
        alert.group = id
        ::continue::
    end
    for id, alert in pairs(alerts) do
        alert.count = alert.count + 1
        if alert.count >= 600 then
            local group = groups[alert.group]
            group.count = group.count - 1
            alerts[id] = nil
        end
    end
end

---@param player LuaPlayer
---@param alert_name string
local function update_gui(player, alert_name)
    local refs = global.players[player.index]
    local alert_flow = refs[alert_name]
    local groups = refs.groups[alert_name]
    local game_tick = game.tick

    for id, group in pairs(groups) do
        if group.count <= 0 then
            groups[id] = nil
            alert_flow[id].destroy()
        elseif not alert_flow[id] then
            glib.add(alert_flow, {
                args = {type = "button", name = id, index = 1, caption = alert_caption(group.count, 0), style = "list_box_item"},
                style_mods = {horizontally_stretchable = true},
                handlers = {[e.on_gui_click] = handlers.zoom_to_world}
            })
        else
            alert_flow[id].caption = alert_caption(group.count, game_tick - group.tick)
        end
    end
end

---@class AlertInfo
---@field name string
---@field icon SpritePath

---@type AlertInfo[]
local alert_info = {
    {name = "turret_fire", icon = "utility/warning_icon"},
    {name = "entity_under_attack", icon = "utility/danger_icon"},
    {name = "entity_destroyed", icon = "utility/destroyed_icon"},
}

script.on_nth_tick(60, function(event)
    if event.tick == 0 then return end
    for _, player in pairs(game.connected_players) do
        for _, alert in pairs(alert_info) do
            update_alerts(player, alert.name)
        end
        if not player.gui.screen.alert_center.visible then return end
        for _, alert in pairs(alert_info) do
            update_gui(player, alert.name)
        end
    end
end)

function handlers.gui_closed(refs)
    refs.alert_center.visible = false
end

function handlers.zoom_to_world(refs, event)
    local element = event.element
    refs.player.zoom_to_world(refs.groups[element.parent.name][element.name].position, 1)
end

glib.add_handlers(handlers, function(event, handler)
    local refs = global.players[event.player_index]
    handler(refs, event)
end)

---@param name string
---@param icon SpritePath
local function alert_header(name, icon)
    return {
        args = {type = "frame", style = "inside_deep_frame"},
        style_mods = {width = 160},
        children = {{
            args = {type = "frame", style = "subheader_frame"},
            style_mods = {horizontally_stretchable = true},
            children = {{
                args = {type = "label", caption = {"", "[img="..icon.."] ", {"alert-type."..name}}, style = "subheader_label"},
                style_mods = {right_padding = 8},
            }}
        }}
    }
end

local function alert_headers()
    local t = {}
    for _, alert in pairs(alert_info) do
        t[#t+1] = alert_header(alert.name, alert.icon)
    end
    return t
end

local function alert_column(name)
    return {
        args = {type = "frame", direction = "vertical", style = "inside_deep_frame"},
        style_mods = {width = 160},
        children = {{
            args = {type = "frame", name = name, direction = "vertical", style = "list_box_frame"},
            style_mods = {vertically_stretchable = true}
        }}
    }
end

local function alert_columns()
    local t = {}
    for _, alert in pairs(alert_info) do
        t[#t+1] = alert_column(alert.name)
    end
    return t
end

defs.alert_gui = {
    args = {type = "frame", name = "alert_center", direction = "vertical"},
    elem_mods = {auto_center = true},
    handlers = {[e.on_gui_closed] = handlers.gui_closed},
    children = {{
        args = {type = "flow", direction = "vertical"},
        style_mods = {vertical_spacing = 0},
        children = {{
            args = {type = "flow", direction = "horizontal"},
            drag_target = "alert_center",
            children = {{
                args = {type = "label", caption = {"gui.alert_center"}, style = "frame_title", ignored_by_interaction = true},
            },{
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {height = 24, right_margin = 4, horizontally_stretchable = true}
            },{
                args = {type = "sprite-button", style = "frame_action_button",
                sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black"},
                handlers = {[e.on_gui_click] = handlers.gui_closed},
            }}
        },{
            args = {type = "flow", direction = "horizontal"},
            children = alert_headers()
        },{
            args = {type = "scroll-pane", style = "naked_scroll_pane"},
            elem_mods = {horizontal_scroll_policy = "never"},
            style_mods = {minimal_height = 140, maximal_height = 560},
            children = {{
                args = {type = "flow", direction = "horizontal"},
                children = alert_columns()
            }}
        }}
    }}
}