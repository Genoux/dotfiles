local function windowRule(spec)
  hl.window_rule(spec)
end

local function layerRule(spec)
  hl.layer_rule(spec)
end

windowRule({
  name = "xwayland-empty-nofocus",
  no_focus = true,
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
})

windowRule({
  name = "xwayland-float-opaque",
  no_blur = true,
  opaque = true,
  border_size = 0,
  no_shadow = true,
  match = { xwayland = true, float = true },
})

windowRule({
  name = "browser-empty-noblur",
  no_blur = true,
  match = { class = "^()$", title = "^()$" },
})

windowRule({ name = "windowrule-slack", float = true, size = "1200 800", match = { class = "^(slack)$" } })
windowRule({ name = "nautilus", float = true, center = true, size = "(monitor_w*0.65) (monitor_h*0.65)", opacity = "0.90 0.90", match = { class = "^(org.gnome.Nautilus)$" } })
windowRule({ name = "file-picker-portal", float = true, size = "(monitor_w*0.6) (monitor_h*0.7)", center = true, opacity = "0.90 0.90", match = { class = "^(xdg-desktop-portal-gtk)$" } })
windowRule({ name = "modal-open", float = true, match = { title = "^(Open)$" } })
windowRule({ name = "modal-choose-files", float = true, match = { title = "^(Choose Files)$" } })
windowRule({ name = "modal-save-as", float = true, match = { title = "^(Save As)$" } })
windowRule({ name = "modal-confirm-replace", float = true, match = { title = "^(Confirm to replace files)$" } })
windowRule({ name = "modal-file-operation-progress", float = true, match = { title = "^(File Operation Progress)$" } })
windowRule({ name = "system-info", float = true, center = true, size = "1016 480", match = { class = "^(system-info)$" } })
windowRule({ name = "caprine", float = true, center = true, size = "490 700", match = { class = "^(Caprine)$" } })
windowRule({ name = "calcurse", float = true, size = "1000 800", center = true, match = { class = "^(calcurse)$" } })
windowRule({ name = "mpv", float = true, center = true, size = "(monitor_w*0.3) (monitor_h*0.3)", pin = true, match = { class = "^(mpv)$" } })
windowRule({ name = "live-cam", float = true, center = true, size = "1280 720", match = { initial_title = ".*cam\\.jbroom\\.ca.*" } })
windowRule({ name = "bluetui", float = true, center = true, size = "700 700", match = { title = "^(bluetui)$" } })
windowRule({ name = "impala-wifi", float = true, center = true, size = "1024 700", match = { title = "^(impala)$" } })
windowRule({ name = "kitty-float", float = true, center = true, size = "1000 600", match = { title = "^(kitty)$" } })
windowRule({ name = "btop", float = true, center = true, size = "1024 600", match = { title = "^(btop)$" } })
windowRule({ name = "battop", float = true, center = true, size = "1024 700", match = { title = "^(battop)$" } })
windowRule({ name = "wiremix", float = true, center = true, size = "800 700", match = { title = "^(wiremix)$" } })
windowRule({ name = "gnome-weather", float = true, center = true, size = "900 650", match = { class = "^(org\\.gnome\\.Weather)$" } })
windowRule({ name = "wthrr", float = true, center = true, size = "630 650", match = { title = "^(wthrr)$" } })
windowRule({ name = "clipse", float = true, center = true, size = "700 700", match = { title = "^(clipse)$" } })
windowRule({ name = "windowrule-22", float = true, center = true, size = "628 450", match = { class = "^(dotfiles-manager)$" } })
windowRule({ name = "windowrule-telegram", float = true, center = true, size = "420 640", match = { class = "^(org.telegram.desktop)$" } })
windowRule({ name = "gnome-calculator", float = true, center = true, size = "628 400", match = { class = "^(org.gnome.Calculator)$" } })

windowRule({
  name = "picture-in-picture",
  pin = true,
  float = true,
  size = "(monitor_w*0.25) (monitor_h*0.25)",
  move = "((monitor_w*1)-(monitor_w*0.255)) ((monitor_h*1)-(monitor_h*0.285))",
  match = { title = "^(Picture-in-Picture)$" },
})

windowRule({
  name = "wisper",
  pin = true,
  float = true,
  size = "(monitor_w*0.15) (monitor_h*0.15)",
  move = "((monitor_w*0.5)-(monitor_w*0.075)) ((monitor_h*1)-(monitor_h*0.2))",
  match = { class = "^(wisper)$" },
})

windowRule({ name = "satty", size = "1280 800", center = true, float = true, match = { title = "^(satty)$" } })

layerRule({ name = "osd", blur = true, ignore_alpha = 0.0, blur_popups = true, animation = "fade", match = { namespace = "osd" } })
layerRule({ name = "layerrule-brightness-osd", blur = true, ignore_alpha = 0.0, blur_popups = true, animation = "fade", match = { namespace = "^(brightness-osd)$" } })
layerRule({ name = "layerrule-ags-bar", blur = true, blur_popups = true, ignore_alpha = 0.1, animation = "fade", match = { namespace = "^(ags-bar)$" } })
layerRule({ name = "layerrule-quickshell", blur = true, blur_popups = true, ignore_alpha = 0.1, animation = "fade", match = { namespace = "^(quickshell)$" } })
layerRule({ name = "gtk4-layer-shell", blur = true, blur_popups = true, ignore_alpha = 0.1, match = { namespace = "gtk4-layer-shell" } })

windowRule({ name = "claude-desktop", float = true, center = true, size = "1280 800", match = { class = "^(Claude|com\\.anthropic\\.claude-desktop)$" } })

layerRule({ name = "notifications", blur = true, ignore_alpha = 0.0, match = { namespace = "notifications" } })
layerRule({ name = "walker", blur = true, ignore_alpha = 0.1, no_anim = true, match = { namespace = "^(walker)$" } })

windowRule({
  name = "idleon-game",
  size = "(monitor_w*0.79) (monitor_h*0.79)",
  center = true,
  float = true,
  opacity = "1.0",
  match = { initial_title = "www.legendsofidleon.com_/ytGl5oc/" },
})
