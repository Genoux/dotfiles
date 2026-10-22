hl.config({
  general = {
    border_size = 1,
    no_focus_fallback = false,
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding_power = 2,
    rounding = 14,
    active_opacity = 0.95,
    inactive_opacity = 0.93,
    dim_special = 0.3,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      noise = 0.015,
      contrast = 1.0,
      brightness = 1.0,
      vibrancy = 0.2,
      vibrancy_darkness = 0.2,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
      special = true,
    },

    shadow = {
      enabled = true,
      range = 24,
      render_power = 3,
      offset = "0 6",
      color = "rgba(00000047)",
      color_inactive = "rgba(00000024)",
    },
  },
})
