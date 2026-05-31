local home = os.getenv("HOME") or "/home/john"

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_CLASS", "user")

hl.env("GTK_USE_PORTAL", "0")
hl.env("QT_WAYLAND_DISABLE_SELECTION", "1")
hl.env("HYPRLAND_NO_SD_NOTIFY", "1")

hl.env("PATH", "$HOME/.local/bin:$HOME/dotfiles/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/var/lib/flatpak/exports/bin:/usr/lib/jvm/default/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl")

hl.env("CLUTTER_BACKEND", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")

hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.env("GTK_IM_MODULE", "wayland")
hl.env("GTK_CSD", "0")
hl.env("HL_INITIAL_WORKSPACE_TOKEN", "0")
hl.env("GDK_DECORATION_LAYOUT", "")

hl.env("GTK2_RC_FILES", "/home/john/.gtkrc-2.0")
hl.env("GTK_KEY_THEME_NAME", "Emacs")

hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_WEBRENDER", "1")
hl.env("MOZ_GTK_TITLEBAR_DECORATION", "client")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("ELECTRON_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_DISABLE_FRAME", "1")
hl.env("ELECTRON_DISABLE_DEFAULT_MENU_BAR", "1")

hl.env("GTK_THEME", "MacTahoe-Dark")
hl.env("XCURSOR_PATH", home .. "/.local/share/icons:" .. home .. "/.icons:/usr/share/icons:/usr/share/pixmaps")

hl.env("TERMINAL", "kitty")
hl.env("JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")

hl.env("WINE_CPU_TOPOLOGY", "4:2")
hl.env("DXVK_ASYNC", "1")
hl.env("DXVK_STATE_CACHE", "1")
hl.env("VKFFT_BACKEND", "2")
hl.env("MESA_SHADER_CACHE_DISABLE", "false")

hl.env("WEATHER_CITY", "Montreal")
