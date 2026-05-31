local paths = require("actions.paths")

local M = {}

local function screenshotCommand(geometry)
  local geometryArg = geometry and "-g " .. paths.shellQuote(geometry) .. " " or ""
  return "sh -c " .. paths.shellQuote(
    'source "$HOME/.config/user-dirs.dirs" 2>/dev/null || true; ' ..
    'output_dir="${SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"; ' ..
    'mkdir -p "$output_dir"; ' ..
    'file="$output_dir/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"; ' ..
    "grim " .. geometryArg .. '- | satty --filename - --output-filename "$file"'
  )
end

local function screenshotGeometry(geometry)
  hl.dispatch(hl.dsp.exec_cmd(screenshotCommand(geometry)))
end

local function activeMonitorGeometry()
  local monitor = hl.get_active_monitor()
  if monitor == nil then
    return nil
  end

  local width = monitor.width
  local height = monitor.height
  if monitor.transform % 2 ~= 0 then
    width = monitor.height
    height = monitor.width
  end

  return string.format("%d,%d %dx%d", monitor.x, monitor.y, width, height)
end

local function activeWindowGeometry()
  local window = hl.get_active_window()
  if window == nil then
    return nil
  end

  return string.format("%d,%d %dx%d", window.at[1], window.at[2], window.size[1], window.size[2])
end

function M.region()
  hl.dispatch(hl.dsp.exec_cmd(
    "sh -c " .. paths.shellQuote(
      'source "$HOME/.config/user-dirs.dirs" 2>/dev/null || true; ' ..
      'output_dir="${SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"; ' ..
      'mkdir -p "$output_dir"; ' ..
      'file="$output_dir/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"; ' ..
      'geometry="$(slurp)" || exit 1; ' ..
      '[ -n "$geometry" ] || exit 1; ' ..
      'sleep 0.4; ' ..
      'grim -g "$geometry" - | satty --filename - --output-filename "$file"'
    )
  ))
end

function M.output()
  local geometry = activeMonitorGeometry()
  if geometry ~= nil then
    screenshotGeometry(geometry)
  end
end

function M.window()
  local geometry = activeWindowGeometry()
  if geometry ~= nil then
    screenshotGeometry(geometry)
  end
end

return M
