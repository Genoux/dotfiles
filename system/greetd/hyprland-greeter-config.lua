-- Hyprland configuration for greetd greeter session
-- Monitors auto-detected by Hyprland at runtime

hl.config({
  animations = {
    enabled = false,
  },

  decoration = {
    rounding = 0,
    blur = {
      enabled = false,
    },
  },

  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    background_color = "rgb(000000)",
    -- greetd starts Hyprland directly; it cannot pass the watchdog fd start-hyprland expects
    disable_watchdog_warning = true,
    -- Greeter has no lockscreen app - don't try to restore lock state
    allow_session_lock_restore = false,
  },

  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },

  input = {
    kb_layout = "us",
    repeat_delay = 400,
    repeat_rate = 40,

    touchpad = {
      tap_to_click = true,
    },
  },
})

hl.window_rule({
  name = "greeter-kitty-fullscreen",
  fullscreen = true,
  opacity = "1.0",
  match = { class = "^(kitty)$" },
})

hl.layer_rule({
  name = "greeter-wallpaper-blur",
  blur = true,
  match = { namespace = "wallpaper" },
})

hl.exec_cmd("gslapper -f -I /tmp/sysc-greet-wallpaper.sock '*' /usr/share/sysc-greet/wallpapers/sysc-greet-default.png")
hl.exec_cmd(
  "XDG_CACHE_HOME=/tmp/greeter-cache HOME=/var/lib/greeter kitty --start-as=fullscreen --config=/etc/greetd/kitty.conf /usr/local/bin/sysc-greet && hyprctl dispatch exit"
)
