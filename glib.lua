local mod_name = "__"..script.mod_name.."__/handlers"

local handler_funcs = {}
local handler_names = {}

local function error_def(def, s)
    error(s.."\n"..serpent.block(def, {maxlevel = 1, sortkeys = false}))
end

--- Adds one or more GUI elements to a parent GUI element.
--- @param parent LuaGuiElement The parent element to add new elements to.
--- @param def GuiElemDef The element definition(s) to add to the parent.
--- @param elems? table<string, LuaGuiElement> The table to add new element references to.
--- @return LuaGuiElement elem The topmost element added to the parent.
--- @return table<string, LuaGuiElement> elems The table of element references, indexed by element name.
local function add(parent, def, elems)
    elems = elems or {} --[[@as table<string, LuaGuiElement>]]
    local elem
    if def.args then
        local args = def.args
        local children = def.children
        if def[1] then
            if children then
                error_def(def, "Cannot define children in array portion and subtable simultaneously.")
            end
            children = {}
            for i = 1, #def do
                children[i] = def[i]
            end
        end
        local tags = args.tags
        if tags and tags[mod_name] then
            error_def(def, "Tag index \""..mod_name.."\" is reserved for GUI Library.")
        end
        local handlers = def.handlers
        if handlers then
            local handler_tags
            if type(handlers) == "table" then
                handler_tags = {}
                for event, handler in pairs(handlers) do
                    if type(event) == "string" then
                        event = defines.events[event]
                        if not event then error_def(def, "Event \"" .. event .. "does not exist.") end
                    end
                    handler_tags[tostring(event)] = handler_names[handler]
                end
            else
                handler_tags = handler_names[def.handlers]
            end
            args.tags = tags or {}
            args.tags[mod_name] = handler_tags
        end
        elem = parent.add(args) --[[@as LuaGuiElement]]
        if tags then
            args.tags[mod_name] = nil
        else
            args.tags = nil
        end
        if args.name and def.ref ~= false then
            local ref = def.ref or args.name --[[@as string]]
            elems[ref] = elem
        end
        if def.elem_mods then
            for k, v in pairs(def.elem_mods) do
                elem[k] = v
            end
        end
        if def.style_mods then
            for k, v in pairs(def.style_mods) do
                elem.style[k] = v
            end
        end
        if def.drag_target then
            local target = elems[def.drag_target]
            if not target then
                error_def(def, "Drag target \""..def.drag_target.."\" does not exist.")
            end
            elem.drag_target = target
        end
        if children then
            for _, child in pairs(children) do
                add(elem, child, elems)
            end
        end
    elseif def.tab and def.content then
        elems = elems or {}
        local tab = add(parent, def.tab, elems) --- @cast tab LuaGuiElement
        local content = add(parent, def.content, elems) --- @cast content LuaGuiElement
        parent.add_tab(tab, content)
    else
        if type(def) ~= table then def = defs end
        error_def(def, "Invalid GUI element definition:")
    end
    return elem, elems
end

--- @param event GuiEventData
--- @return boolean
local function event_handler(event)
    local element = event.element
    if not element then return false end
    local tags = element.tags
    local handler_def = tags[mod_name]
    if not handler_def then return false end
    if type(handler_def) == "table" then
        handler_def = handler_def[tostring(event.name)]
    end
    if not handler_def then return false end
    local handler = handler_funcs[handler_def]
    if not handler then return false end
    handler(event)
    return true
end

for name, id in pairs(defines.events) do
    if name:find("on_gui_") then
        script.on_event(id, event_handler)
    end
end

---Adds event handlers for glib to call when an element has a `handlers` table specified.
---@param handlers table<string, fun(e:GuiEventData)> The table of handlers for glib to call.
---@param wrapper fun(e:GuiEventData, handler:function)? (Optional) The wrapper function to call instead of the event handler directly.
local function add_handlers(handlers, wrapper)
    for name, handler in pairs(handlers) do
        if type(handler) == "function" then
            if handler_funcs[name] then
                error("Attempt to register handler function with duplicate name \""..name.."\".")
            end
            if handler_names[handler] then
                error("Attempt to register duplicate handler function.")
            end
            handler_names[handler] = name
            if wrapper then
                handler_funcs[name] = function(e)
                    wrapper(e, handler)
                end
            else
                handler_funcs[name] = handler
            end
        end
    end
end

---Sets the tags of an element.
---@param elem LuaGuiElement The element to set the tags of.
---@param tags Tags The tags to set.
local function set_tags(elem, tags)
    local elem_tags = elem.tags
    for k, v in pairs(tags) do
        elem_tags[k] = v
    end
    elem.tags = elem_tags
end

return {
    add = add,
    add_handlers = add_handlers,
    set_tags = set_tags,
}

---@diagnostic disable: duplicate-doc-field
---@class GuiElemDef
---@field args LuaGuiElement.add_param
---@field ref? string|false
---@field drag_target? string
---@field elem_mods? LuaGuiElement
---@field style_mods? LuaStyle
---@field handlers? GuiEventHandler
---@field children? GuiElemDef[]
---@field tab? GuiElemDef
---@field content? GuiElemDef

---@alias GuiEventHandler fun(e:GuiEventData)|table<string|defines.events, fun(event:GuiEventData)>
---@alias GuiEventData
---|EventData.on_gui_checked_state_changed
---|EventData.on_gui_click
---|EventData.on_gui_closed
---|EventData.on_gui_confirmed
---|EventData.on_gui_elem_changed
---|EventData.on_gui_hover
---|EventData.on_gui_leave
---|EventData.on_gui_location_changed
---|EventData.on_gui_opened
---|EventData.on_gui_selected_tab_changed
---|EventData.on_gui_selection_state_changed
---|EventData.on_gui_switch_state_changed
---|EventData.on_gui_text_changed
---|EventData.on_gui_value_changed