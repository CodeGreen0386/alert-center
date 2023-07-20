local styles = data.raw["gui-style"].default

data:extend{{
    type = "sprite",
    name = "pin-black",
    filename = "__alert-center__/graphics/pin_black.png",
    size = 32,
    flags = {"gui-icon"},
},{
    type = "sprite",
    name = "pin-white",
    filename = "__alert-center__/graphics/pin_white.png",
    size = 32,
    flags = {"gui-icon"},
}}

styles.titlebar_flow = {
    type = "horizontal_flow_style",
    horizontal_spacing = 8,
}

styles.list_box_frame = {
    type = "frame_style",
    padding = 0,
    horizontally_stretchable = "on",
    graphical_set = {
      base = {
        position = {17, 0},
        corner_size = 8,
        center = {position = {42, 8}, size = 1},
        top = {},
        left_top = {},
        right_top = {},
        draw_type = "outer"
      },
      shadow = default_inner_shadow
    },
    background_graphical_set = {
        position = {282, 17},
        corner_size = 8,
        overall_tiling_vertical_size = 20,
        overall_tiling_vertical_spacing = 8,
        overall_tiling_vertical_padding = 4,
        overall_tiling_horizontal_padding = 4
    },
    vertical_flow_style = {
        type = "vertical_flow_style",
        vertical_spacing = 0
    },
}

data:extend{{
    type = "custom-input",
    name = "alert-center",
    key_sequence = "SHIFT + ALT + A",
    action = "lua"
},{
    type = "shortcut",
    name = "alert-center",
    action = "lua",
    localised_name = {"gui.alert_center"},
    icon = {
        filename = "__core__/graphics/icons/mip/warning.png",
        priority = "extra-high-no-scale",
        size = 32,
        mipmap_count = 2,
        flags = {"gui-icon"}
    },
    disabled_icon = {
        filename = "__core__/graphics/icons/mip/warning-white.png",
        priority = "extra-high-no-scale",
        size = 32,
        mipmap_count = 2,
        flags = {"gui-icon"}
    },
    order = "zzzzz"
}}