-- Personal overrides are loaded last so they win over the base modules.
--
-- Workspace bind count and monitor hints live in config/workspaces.lua.
-- Override here if needed, e.g.:
--   package.loaded["config.workspaces"] = nil
--   local workspaces = require("config.workspaces")
--   workspaces.workspace_count = 6

local home = os.getenv("HOME") or "/home/john"
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local secrets_path = config .. "/hypr/secrets.lua"

local secrets_file = io.open(secrets_path, "r")
if secrets_file then
  local content = secrets_file:read("*a")
  secrets_file:close()

  local api_key = content:match('hl%.env%("OPENWEATHERMAP_API_KEY"%s*,%s*"(.-)"%)')
    or content:match('os%.environ%("OPENWEATHERMAP_API_KEY"%s*,%s*"(.-)"%)')
  if api_key and api_key ~= "" and api_key ~= "your-openweathermap-api-key" then
    hl.env("OPENWEATHERMAP_API_KEY", api_key)
  end
end
