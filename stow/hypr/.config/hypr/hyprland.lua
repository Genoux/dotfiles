local modules = {
  "gpu",
  "monitors",
  "env",
  "input",
  "misc",
  "plugins",
  "animations",
  "keybindings",
  "windowrules",
  "themes.common",
  "themes.theme",
  "themes.colors",
  "autostart",
  "userprefs",
}

for _, module in ipairs(modules) do
  package.loaded[module] = nil
  require(module)
end

-- Permissions require a Hyprland restart after changes.
hl.permission({ binary = "/usr/(bin|local/bin)/grim", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm", type = "plugin", mode = "allow" })
