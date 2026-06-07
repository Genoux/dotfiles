hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 8,
    border_size = 1,
    no_focus_fallback = false,
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding_power = 2,
    rounding = 10,
    active_opacity = 0.95,
    inactive_opacity = 0.93,
    dim_special = 0.3,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
      special = true,
    },

    shadow = {
      enabled = true,
      range = 50,
      render_power = 4,
      offset = "0 20",
      color = "rgba(00000026)",
      color_inactive = "rgba(00000014)",
    },
  },
})
