-- Personal overrides are loaded last so they win over the base modules.
--
-- Workspace bind count and monitor hints live in config/workspaces.lua.
-- Override here if needed, e.g.:
--   package.loaded["config.workspaces"] = nil
--   local workspaces = require("config.workspaces")
--   workspaces.workspace_count = 6


-- 120Hz, not the panel's max 144Hz: VG278H has no adaptive sync (EDID carries no
-- AMD vendor block), so a fixed rate must divide the video framerate evenly.
-- 144/60 = 2.4 judders; 120 divides 60, 30 and 24 exactly.
hl.monitor({
  output = "desc:ASUSTek COMPUTER INC VG278 H9LMQS099647",
  mode = "1920x1080@119.98",
  position = "0x0",
  scale = 1,
})
