local paths = require("actions.paths")

local M = {}

-- One path for every capture, so a keybind and the bar's capture widget produce
-- the same result: the file saved, the clipboard filled, and the shell told so
-- it can offer copy, edit, and discard. This file used to reimplement the
-- script's grim/slurp/satty pipeline inline, which meant the keybinds and the
-- script could drift and only the script's callers got the preview card.
local function shoot(mode)
  hl.dispatch(hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.systemScreenshot) .. " " .. mode))
end

function M.region()
  shoot("region")
end

function M.output()
  shoot("output")
end

function M.window()
  shoot("window")
end

return M
