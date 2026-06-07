-- Declarative workspace layout: keybind loops and monitor hints read from here.
-- Override counts or monitor ranges in userprefs.lua if needed.
local M = {}

M.workspace_count = 10

-- Global workspace IDs; home ranges are hints for multi-monitor setups / hyprexpo.
M.monitors = {
  {
    output = "eDP-1",
    workspaces = { 1, 2, 3, 4, 5 },
  },
  {
    output = "HDMI-A-1",
    workspaces = { 6, 7, 8, 9, 10 },
  },
}

return M
