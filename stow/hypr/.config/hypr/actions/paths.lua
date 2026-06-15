local M = {}

M.home = os.getenv("HOME") or "/home/john"
M.localBin = M.home .. "/.local/bin"

M.scripts = {
  launchDotfilesMenu = M.localBin .. "/launch-dotfiles-menu",
  systemPickWallpaper = M.localBin .. "/system-pick-wallpaper",
  systemScreenrecord = M.localBin .. "/system-screenrecord",
}

function M.shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

return M
