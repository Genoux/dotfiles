hl.window_rule({
  name = "xwayland-empty-nofocus",
  no_focus = true,
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
})

hl.window_rule({
  name = "xwayland-float-opaque",
  no_blur = true,
  opaque = true,
  border_size = 0,
  no_shadow = true,
  match = { xwayland = true, float = true },
})

hl.window_rule({
  name = "browser-empty-noblur",
  no_blur = true,
  match = { class = "^()$", title = "^()$" },
})

hl.window_rule({ name = "windowrule-slack", float = true, size = "1200 800", match = { class = "^(slack)$" } })
hl.window_rule({ name = "nautilus", float = true, center = true, size = "(monitor_w*0.65) (monitor_h*0.65)", opacity = "0.90 0.90", match = { class = "^(org.gnome.Nautilus)$" } })
hl.window_rule({ name = "file-picker-portal", float = true, size = "(monitor_w*0.6) (monitor_h*0.7)", center = true, opacity = "0.90 0.90", match = { class = "^(xdg-desktop-portal-gtk)$" } })
hl.window_rule({ name = "modal-open", float = true, match = { title = "^(Open)$" } })
hl.window_rule({ name = "modal-choose-files", float = true, match = { title = "^(Choose Files)$" } })
hl.window_rule({ name = "modal-save-as", float = true, match = { title = "^(Save As)$" } })
hl.window_rule({ name = "modal-confirm-replace", float = true, match = { title = "^(Confirm to replace files)$" } })
hl.window_rule({ name = "modal-file-operation-progress", float = true, match = { title = "^(File Operation Progress)$" } })
hl.window_rule({ name = "system-info", float = true, center = true, size = "1016 480", match = { class = "^(system-info)$" } })
hl.window_rule({ name = "caprine", float = true, center = true, size = "490 700", match = { class = "^(Caprine)$" } })
hl.window_rule({ name = "calcurse", float = true, size = "1000 800", center = true, match = { class = "^(calcurse)$" } })
hl.window_rule({ name = "mpv", float = true, center = true, size = "(monitor_w*0.3) (monitor_h*0.3)", pin = true, match = { class = "^(mpv)$" } })
hl.window_rule({ name = "live-cam", float = true, center = true, size = "1280 720", match = { initial_title = ".*cam\\.jbroom\\.ca.*" } })
hl.window_rule({ name = "bluetui", float = true, center = true, size = "700 700", match = { title = "^(bluetui)$" } })
hl.window_rule({ name = "impala-wifi", float = true, center = true, size = "1024 700", match = { title = "^(impala)$" } })
hl.window_rule({ name = "kitty-float", float = true, center = true, size = "1000 600", match = { title = "^(kitty)$" } })
hl.window_rule({ name = "btop", float = true, center = true, size = "1024 600", match = { title = "^(btop)$" } })
hl.window_rule({ name = "battop", float = true, center = true, size = "1024 700", match = { title = "^(battop)$" } })
hl.window_rule({ name = "wiremix", float = true, center = true, size = "800 700", match = { title = "^(wiremix)$" } })
hl.window_rule({ name = "gnome-weather", float = true, center = true, size = "900 650", match = { class = "^(org\\.gnome\\.Weather)$" } })
hl.window_rule({ name = "wthrr", float = true, center = true, size = "630 650", match = { title = "^(wthrr)$" } })
hl.window_rule({ name = "clipse", float = true, center = true, size = "700 700", match = { title = "^(clipse)$" } })
hl.window_rule({ name = "dotfiles-manager", float = true, center = true, size = "628 450", match = { class = "^(dotfiles-manager)$" } })
hl.window_rule({ name = "windowrule-telegram", float = true, center = true, size = "420 640", match = { class = "^(org.telegram.desktop)$" } })
hl.window_rule({ name = "gnome-calculator", float = true, center = true, size = "628 400", match = { class = "^(org.gnome.Calculator)$" } })
hl.window_rule({ name = "gnome-calendar", float = true, center = true, size = "1280 750", match = { class = "^(org.gnome.Calendar)$" } })

hl.window_rule({
  name = "picture-in-picture",
  pin = true,
  float = true,
  size = "(monitor_w*0.25) (monitor_h*0.25)",
  move = "((monitor_w*1)-(monitor_w*0.255)) ((monitor_h*1)-(monitor_h*0.285))",
  match = { title = "^(Picture-in-Picture)$" },
})

hl.window_rule({
  name = "wisper",
  pin = true,
  float = true,
  size = "(monitor_w*0.15) (monitor_h*0.15)",
  move = "((monitor_w*0.5)-(monitor_w*0.075)) ((monitor_h*1)-(monitor_h*0.2))",
  match = { class = "^(wisper)$" },
})

hl.window_rule({ name = "satty", size = "1280 800", center = true, float = true, match = { title = "^(satty)$" } })

hl.layer_rule({ name = "osd", blur = true, ignore_alpha = 0.0, blur_popups = true, animation = "fade", match = { namespace = "osd" } })
hl.layer_rule({ name = "layerrule-brightness-osd", blur = true, ignore_alpha = 0.0, blur_popups = true, animation = "fade", match = { namespace = "^(brightness-osd)$" } })
hl.layer_rule({ name = "layerrule-ags-bar", blur = true, blur_popups = true, ignore_alpha = 0.1, animation = "fade", match = { namespace = "^(ags-bar)$" } })
hl.layer_rule({ name = "layerrule-quickshell", blur = true, blur_popups = true, ignore_alpha = 0.1, animation = "fade", match = { namespace = "^(quickshell)$" } })
hl.layer_rule({ name = "layerrule-calendar", blur = true, blur_popups = true, ignore_alpha = 0.1, animation = "fade", match = { namespace = "^(calendar_widget)$" } })
hl.layer_rule({ name = "gtk4-layer-shell", blur = true, blur_popups = true, ignore_alpha = 0.1, match = { namespace = "gtk4-layer-shell" } })

hl.window_rule({ name = "claude-desktop", float = true, center = true, size = "1280 800", match = { class = "^(Claude|com\\.anthropic\\.claude-desktop)$" } })

hl.layer_rule({ name = "notifications", blur = true, ignore_alpha = 0.0, match = { namespace = "notifications" } })
hl.layer_rule({ name = "walker", blur = true, ignore_alpha = 0.1, no_anim = true, match = { namespace = "^(walker)$" } })
hl.layer_rule({ name = "launcher-backdrop", no_anim = true, match = { namespace = "^(launcher-backdrop)$" } })
hl.layer_rule({ name = "launcher", blur = true, ignore_alpha = 0.1, no_anim = true, match = { namespace = "^(launcher)$" } })
hl.layer_rule({ name = "power-menu-backdrop", no_anim = true, match = { namespace = "^(power-menu-backdrop)$" } })
hl.layer_rule({ name = "power-menu", blur = true, ignore_alpha = 0.1, no_anim = true, match = { namespace = "^(power-menu)$" } })

hl.window_rule({
  name = "idleon-game",
  size = "(monitor_w*0.79) (monitor_h*0.79)",
  center = true,
  float = true,
  opacity = "1.0",
  match = { initial_title = "www.legendsofidleon.com_/ytGl5oc/" },
})
