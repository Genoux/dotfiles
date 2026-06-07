local sessionEnvironment =
  "WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP XCURSOR_THEME XCURSOR_SIZE XCURSOR_PATH HYPRCURSOR_SIZE GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME LIBVA_DRIVER_NAME WLR_DRM_DEVICES WLR_RENDER_DRM_DEVICE WLR_NO_HARDWARE_CURSORS WEATHER_CITY"

local desktopServices = {
  -- "ags.service", -- Hyprland autostart off while quickshell is the bar; dotfiles config link starts it
  "walker.service",
  "elephant.service",
  "mako.service",
  "awww-daemon.service",
  "hypridle.service",
}

local portalServices = {
  "xdg-desktop-portal.service",
  "xdg-desktop-portal-hyprland.service",
  "xdg-desktop-portal-gtk.service",
}

local startupCommands = {
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
  "hyprpm reload -n",
  "gsettings set org.gnome.desktop.wm.preferences button-layout appmenu",
  "xdg-settings set default-web-browser firefox.desktop",
  "system-pick-wallpaper",
  "system-bluetooth-reconnect",
  "wl-paste -p --watch wl-copy -pc",
  "clipse -listen",
}

hl.on("hyprland.start", function()
  hl.exec_cmd(table.concat({
    "dbus-update-activation-environment --systemd " .. sessionEnvironment,
    "systemctl --user import-environment " .. sessionEnvironment,
    "systemctl --user reset-failed "
      .. table.concat(portalServices, " ")
      .. " "
      .. "hyprsession.service "
      .. table.concat(desktopServices, " "),
    "systemctl --user start xdg-desktop-portal-hyprland.service || true",
    "systemctl --user start " .. table.concat(desktopServices, " "),
  }, "; "))

  for _, command in ipairs(startupCommands) do
    hl.exec_cmd(command)
  end

  -- Restore before the save loop; never block shutdown (that froze logout for seconds).
  local home = os.getenv("HOME") or ""
  local hyprsession = home .. "/.local/bin/system-hyprsession"
  local restoreState = home .. "/.local/state/hyprsession"
  hl.exec_cmd(
    "rm -f "
      .. restoreState
      .. "/restored-*; sleep 8; "
      .. hyprsession
      .. " load; systemctl --user start hyprsession.service"
  )
end)

hl.on("hyprland.shutdown", function()
  hl.exec_cmd(
    "systemctl --user stop hyprsession.service "
      .. table.concat(desktopServices, " ")
      .. " "
      .. table.concat(portalServices, " ")
  )
end)
