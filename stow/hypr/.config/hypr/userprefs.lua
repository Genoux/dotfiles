-- Personal overrides are loaded last so they win over the base modules.
--
-- Workspace bind count and monitor hints live in config/workspaces.lua.
-- Override here if needed, e.g.:
--   package.loaded["config.workspaces"] = nil
--   local workspaces = require("config.workspaces")
--   workspaces.workspace_count = 6

local home = os.getenv("HOME") or "/home/john"
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local secrets_chunk = loadfile(config .. "/hypr/secrets.lua")

if secrets_chunk then
  secrets_chunk()
end
