local paths = require("actions.paths")

local M = {}

local dotfilesTitle = "Dotfiles Manager"
local launchScript = paths.localBin .. "/launch-or-focus"

local function shellJoin(parts)
  return table.concat(parts, " ")
end

function M.openDotfilesManager()
  local selector = "title:" .. dotfilesTitle
  if hl.get_window(selector) ~= nil then
    hl.dispatch(hl.dsp.focus({ window = selector }))
    return
  end

  hl.dispatch(hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.launchDotfilesMenu)))
end

function M.launchOrFocus(title, command, className, ...)
  className = className or title
  local selector = "title:" .. title
  if hl.get_window(selector) ~= nil then
    hl.dispatch(hl.dsp.focus({ window = selector }))
    return
  end

  local innerParts = {
    "env LAUNCH_OR_FOCUS_DISPLAY=1",
    paths.shellQuote(launchScript),
    paths.shellQuote(title),
    paths.shellQuote(command),
    paths.shellQuote(className),
  }

  for index = 1, select("#", ...) do
    innerParts[#innerParts + 1] = paths.shellQuote(select(index, ...))
  end

  -- Ghostty ignores a class that is not a GTK application id (it needs a dot),
  -- so the prefix keeps per-TUI classes; IconRegistry strips it for icon lookup.
  local launchCommand = shellJoin({
    "ghostty",
    paths.shellQuote("--class=tui." .. className),
    paths.shellQuote("--title=" .. title),
    "-e",
    shellJoin(innerParts),
    "&",
  })

  hl.exec_cmd(launchCommand)
end

return M
