local glib = require("glib")
local e = defines.events
local handlers = {}
local defs = {}
local poll_rate = 60

--- @type table<string, SpritePath> name to info
local alert_info = {
    turret_fire = "utility/warning_icon",
    entity_under_attack = "utility/danger_icon",
    entity_destroyed = "utility/destroyed_icon",
}

--- @class Group
--- @field count integer
--- @field position MapPosition
--- @field tick uint
--- @field alerts table<AlertID,Alert>

--- @alias GroupID string tostring of an integer that just counts up (refs.next_group_id)
--- @alias AlertID string alert.position.x..","..alert.position.y

--- @class SavedAlert
--- @field count integer more like a timer
--- @field group GroupID

--- @param player LuaPlayer
--- @return LuaGuiElement
local function create_gui(player)
    global.players[player.index] = {
        player = player,
        groups = {
            turret_fire = {}, --- @type table<GroupID,Group>
            entity_under_attack = {}, --- @type table<GroupID,Group>
            entity_destroyed = {}, --- @type table<GroupID,Group>
        },
        alerts = {
            turret_fire = {}, --- @type table<AlertID,SavedAlert>
            entity_under_attack = {}, --- @type table<AlertID,SavedAlert>
            entity_destroyed = {}, --- @type table<AlertID,SavedAlert>
        },
        next_group_id = 1,
        renderings = {},
    }
    local refs = global.players[player.index]
    local gui = glib.add(player.gui.screen, defs.alert_gui, refs)
    return gui
end

--- @param player LuaPlayer
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
    local pre = ""
    local post = m < 3 and "[/color][/font]" or ""
    if m == 0 then
        pre = "[font=default-bold][color=red]"
    elseif m < 3 then
        pre = "[font=default-bold][color=yellow]"
    end
    return pre .. string.format("%d:%02d", m, s) .. post
end

local function alert_caption(count, time)
    return {"", {"alert-caption.count", count}, " (", format_time(time), ")"}
end

--- @param player LuaPlayer
local function update_alerts(player)
    for name in pairs(alert_info) do
        local alert_type = defines.alert_type[name] --[[@as defines.alert_type]]
        local polled_alerts = player.get_alerts{surface = player.surface, type = alert_type}
        if not next(polled_alerts) then return end

        local new_alerts = polled_alerts[player.surface.index][alert_type]
        local refs = global.players[player.index]
        local alerts = refs.alerts[name] --- @type table<AlertID,SavedAlert>
        local groups = refs.groups[name] --- @type table<GroupID,Group>
        local game_tick = game.tick
        for _, new_alert in pairs(new_alerts) do
            local position = new_alert.position --[[@as MapPosition]]
            local alert_id = position.x..","..position.y --- @type AlertID
            if alerts[alert_id] then
                local group = alerts[alert_id].group
                if new_alert.tick > groups[group].tick then
                    groups[group].tick = new_alert.tick
                end
                goto continue
            end

            local alert = {count = 0} --- @type SavedAlert
            alerts[alert_id] = alert
            for group_id, group in pairs(groups) do
                local dist = vec.mag(vec.sub(group.position, position))
                if dist <= 32 then
                    alert.group = group_id
                    group.count = group.count + 1
                    group.tick = game_tick
                    group.alerts[alert_id] = new_alert
                    group.position = vec.add(vec.div(vec.sub(position, group.position), vec.new(group.count)), group.position)
                    goto continue
                end
            end
            local group_id = tostring(refs.next_group_id)
            refs.next_group_id = refs.next_group_id + 1
            if groups[group_id] then
                error("Trying to create new group with id that is already taken. Id: " .. group_id)
            end

            local group = {
                count = 1,
                tick = game_tick,
                alerts = {[alert_id] = new_alert},
                position = position
            } --- @type Group
            groups[group_id] = group
            alert.group = group_id
            ::continue::
        end

        for alert_id, alert in pairs(alerts) do
            alert.count = alert.count + 1
            if alert.count >= 36000 / poll_rate then
                local group = groups[alert.group]
                group.count = group.count - 1
                alerts[alert_id] = nil
                group.alerts[alert_id] = nil
                if group.count <= 0 then
                    groups[alert.group] = nil
                end
            end
        end
    end
end

--- @param player LuaPlayer
local function update_gui(player)
    local refs = global.players[player.index]
    local game_tick = game.tick
    for name in pairs(alert_info) do
        local alert_flow = refs[name] --- @type LuaGuiElement
        local groups = refs.groups[name] --- @type table<GroupID,Group>

        for id, group in pairs(groups) do
            if not alert_flow[id] then
                glib.add(alert_flow, {
                    args = {type = "button", name = id, index = 1, caption = alert_caption(group.count, game_tick - group.tick), style = "list_box_item"},
                    style_mods = {horizontally_stretchable = true},
                    handlers = {[e.on_gui_click] = handlers.zoom_to_world}
                })
            else
                alert_flow[id].caption = alert_caption(group.count, game_tick - group.tick)
            end
        end

        for _, group_id in pairs(alert_flow.children_names) do
            if not groups[group_id] then
                alert_flow[group_id].destroy()
            end
        end
    end
end

local function open_gui(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local refs = global.players[event.player_index]
    local gui = refs.alert_center
    if not gui then gui = create_gui(player) end
    gui.visible = true
    gui.bring_to_front()
    if not refs.pinned then player.opened = gui end
    update_gui(player)
end

script.on_event("alert-center", open_gui)
script.on_event(defines.events.on_lua_shortcut, function (event)
    if event.prototype_name ~= "alert-center" then return end
    open_gui(event)
end)

script.on_nth_tick(poll_rate, function(event)
    if event.tick == 0 then return end
    for _, player in pairs(game.connected_players) do
        update_alerts(player)
        if not player.gui.screen.alert_center.visible then return end
        update_gui(player)
    end
end)

function handlers.gui_closed(refs)
    if refs.pinned == true then return end
    refs.alert_center.visible = false
end

function handlers.close_button(refs)
    refs.alert_center.visible = false
end

function handlers.pin_clicked(refs)
    local pin_button = refs.pin_button ---@type LuaGuiElement
    if pin_button.toggled then
        pin_button.sprite = "pin-black"
        refs.pinned = true
        refs.player.opened = nil
    else
        pin_button.sprite = "pin-white"
        refs.pinned = false
        refs.player.opened = refs.alert_center
    end
end

local opacity = 0.69
function handlers.zoom_to_world(refs, event)
    local renderings = refs.renderings
    for id in pairs(renderings) do
        rendering.destroy(id)
    end
    local element = event.element
    --- @type Group
    local group = refs.groups[element.parent.name][element.name]
    refs.player.zoom_to_world(group.position, 0.8)
    local sprite = alert_info[element.parent.name]
    for _, alert in pairs(group.alerts) do
        local position = alert.position or alert.target.position
        local offset = alert.prototype.alert_icon_shift
        local scale = alert.prototype.alert_icon_scale
        renderings[rendering.draw_sprite{
            sprite = sprite,
            target = position,
            target_offset = offset,
            surface = refs.player.surface,
            time_to_live = 900, -- 15 * 60
            tint = {opacity, opacity, opacity, opacity},
            x_scale = scale,
            y_scale = scale
        }] = true
    end
end

glib.add_handlers(handlers, function(event, handler)
    local refs = global.players[event.player_index]
    handler(refs, event)
end)

local function alert_headers()
    local t = {}
    for name, icon in pairs(alert_info) do
        t[#t+1] = {
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
    return t
end

local function alert_columns()
    local t = {}
    for name in pairs(alert_info) do
        t[#t+1] = {
            args = {type = "frame", direction = "vertical", style = "inside_deep_frame"},
            style_mods = {width = 160},
            children = {{
                args = {type = "frame", name = name, direction = "vertical", style = "list_box_frame"},
                style_mods = {vertically_stretchable = true}
            }}
        }
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
            args = {type = "flow", direction = "horizontal", style = "titlebar_flow"},
            drag_target = "alert_center",
            children = {{
                args = {type = "label", caption = {"gui.alert_center"}, style = "frame_title", ignored_by_interaction = true},
            },{
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {height = 24, right_margin = 4, horizontally_stretchable = true}
            },{
                args = {type = "sprite-button", name = "pin_button", auto_toggle = true, style = "frame_action_button",
                sprite = "pin-white", hovered_sprite = "pin-black", clicked_sprite = "pin-black"},
                handlers = {[e.on_gui_click] = handlers.pin_clicked}
            },{
                args = {type = "sprite-button", style = "frame_action_button",
                sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black"},
                handlers = {[e.on_gui_click] = handlers.close_button},
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