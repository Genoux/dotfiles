local mainMod = "SUPER"
local browser = "zen-browser"
local terminal = "kitty"
local fileManager = "nautilus"
local appLauncher = "quickshell ipc call launcher toggle"

local function requireAction(name)
  -- Hyprland's root require() can cache `true` for action modules; reload here
  -- so keybindings always get the exported table from actions/*.lua.
  package.loaded[name] = nil
  local module = require(name)
  if type(module) ~= "table" then
    error(name .. " must return a table, got " .. type(module))
  end
  return module
end

local workspaceConfig = requireAction("config.workspaces")

local paths = requireAction("actions.paths")
local windows = requireAction("actions.windows")
local workspaces = requireAction("actions.workspaces")
local screenshots = requireAction("actions.screenshots")
local launchers = requireAction("actions.launchers")

hl.bind(mainMod .. " + t", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + x", hl.dsp.window.close())
hl.bind(mainMod .. " + e", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + b", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + m", hl.dsp.exit())
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("quickshell ipc call powermenu toggle"))

hl.bind(mainMod .. " + v", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + f", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + u", windows.cycleWindowState)
hl.bind(mainMod .. " + j", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + g", hl.dsp.group.toggle())
hl.bind(mainMod .. " + bracketleft", hl.dsp.group.prev())
hl.bind(mainMod .. " + bracketright", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + left", windows.groupAwareMove("left"))
hl.bind(mainMod .. " + SHIFT + right", windows.groupAwareMove("right"))
hl.bind(mainMod .. " + SHIFT + up", windows.groupAwareMove("up"))
hl.bind(mainMod .. " + SHIFT + down", windows.groupAwareMove("down"))
hl.bind(mainMod .. " + SHIFT + g", hl.dsp.group.lock_active("toggle"))

hl.bind(mainMod .. " + a", hl.dsp.exec_cmd(appLauncher))
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ last = true }))
hl.bind(mainMod .. " + d", launchers.openDotfilesManager)
hl.bind(mainMod .. " + l", hl.dsp.exec_cmd("pkill -x hyprlock 2>/dev/null; sleep 0.1; hyprlock"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "special" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })
hl.gesture({ fingers = 4, direction = "up", action = "fullscreen" })

for workspace = 1, workspaceConfig.workspace_count do
  local key = workspace % 10
  local workspaceId = workspace
  hl.bind(mainMod .. " + " .. key, function()
    workspaces.switch(workspaceId)
  end)
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspaceId }))
end

hl.bind("SUPER + SHIFT + s", hl.dsp.window.move({ workspace = "special" }))
hl.bind("SUPER + s", hl.dsp.workspace.toggle_special())

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 10%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl --player=playerctld next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl --player=playerctld play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl --player=playerctld play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl --player=playerctld previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 10%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { repeating = true })

hl.bind("switch:on:Lid Switch", function()
  hl.dsp.exec_cmd("pkill -x hyprlock 2>/dev/null; hyprlock --immediate & sleep 0.1")
  hl.dispatch(hl.dsp.dpms({ action = "off" }))
  hl.dsp.exec_cmd("brightnessctl set 0")
end, { locked = true })
hl.bind("switch:off:Lid Switch", function()
  hl.dispatch(hl.dsp.dpms({ action = "on" }))
  hl.dsp.exec_cmd("brightnessctl -r")
end, { locked = true })

hl.bind("SUPER + SHIFT + code:25", hl.dsp.exec_cmd(paths.scripts.systemPickWallpaper))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(paths.scripts.systemSwitchKeyboard))

hl.bind(mainMod .. " + r", screenshots.region)
hl.bind(mainMod .. " + SHIFT + r", screenshots.output)
hl.bind(mainMod .. " + CTRL + r", screenshots.window)

hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.systemScreenrecord) .. " region"))
hl.bind(mainMod .. " + SHIFT + F10", hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.systemScreenrecord) .. " region audio"))
hl.bind(mainMod .. " + CTRL + F10", hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.systemScreenrecord) .. " fullscreen"))
hl.bind(mainMod .. " + CTRL + SHIFT + F10", hl.dsp.exec_cmd(paths.shellQuote(paths.scripts.systemScreenrecord) .. " fullscreen audio"))

hl.bind("SUPER + c", hl.dsp.exec_cmd("claude-desktop"))
hl.bind("SUPER + SHIFT + c", hl.dsp.exec_cmd(terminal .. " -e claude"))
hl.bind("SUPER + z", hl.dsp.exec_cmd(terminal .. " --title clipse -e clipse"))
hl.bind("SUPER + h", hl.dsp.exec_cmd("caprine"))
hl.bind("SUPER + grave", function()
  if hl.plugin.hyprexpo ~= nil then
    hl.plugin.hyprexpo.expo("toggle")
  end
end)
hl.bind("SUPER + k", hl.dsp.window.kill())
hl.bind("SUPER + SHIFT + p", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + o", hl.dsp.exec_cmd("hypruler"))
hl.bind(mainMod .. " + p", hl.dsp.window.pin())
