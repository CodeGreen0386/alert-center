---@type IntSetting
local setting = {
    type = "int-setting",
    name = "ac-alert-duration",
    setting_type = "runtime-per-user",
    default_value = 10,
    minimum_value = 1,
}

data:extend{setting}