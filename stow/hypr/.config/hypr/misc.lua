hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_watchdog_warning = true,
    vrr = 1,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
    enable_swallow = false,
    swallow_regex = "(foot|kitty|alacritty|Alacritty)",
    on_focus_under_fullscreen = 2,
    allow_session_lock_restore = true,
    session_lock_xray = true,
    initial_workspace_tracking = false,
    focus_on_activate = true,
  },

  xwayland = {
    use_nearest_neighbor = false,
    force_zero_scaling = true,
  },

  binds = {
    workspace_back_and_forth = false,
    allow_workspace_cycles = true,
    focus_preferred_method = 0,
    pass_mouse_when_bound = false,
  },

  cursor = {
    no_warps = true,
    zoom_factor = 1,
    zoom_rigid = false,
    zoom_disable_aa = true,
    hotspot_padding = 1,
  },

  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  debug = {
    disable_logs = false,
    disable_time = false,
  },

  ecosystem = {
    no_update_news = true,
  },
})
