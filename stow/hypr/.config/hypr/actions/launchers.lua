local paths = require("actions.paths")

local M = {}

local dotfilesTitle = "Dotfiles Manager"

function M.openDotfilesManager()
  local selector = "title:" .. dotfilesTitle
  if hl.get_window(selector) ~= nil then
    hl.dispatch(hl.dsp.focus({ window = selector }))
    return
  end

  hl.dispatch(hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.launchDotfilesMenu)))
end

return M
