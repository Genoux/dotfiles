local cursorSettings = {
  theme = "MacTahoe-dark",
  size = "24",
}

local generatedCursorSettings = os.getenv("HOME") .. "/.config/hypr/generated/cursor.lua"
local generatedCursorSettingsFile = io.open(generatedCursorSettings, "r")

if generatedCursorSettingsFile ~= nil then
  generatedCursorSettingsFile:close()

  local loadedCursorSettings = dofile(generatedCursorSettings)
  if type(loadedCursorSettings) == "table" and loadedCursorSettings.theme then
    cursorSettings.theme = loadedCursorSettings.theme
  end
end

hl.env("XCURSOR_THEME", cursorSettings.theme)
hl.env("XCURSOR_SIZE", cursorSettings.size)
hl.env("HYPRCURSOR_SIZE", cursorSettings.size)

hl.config({
  cursor = {
    no_hardware_cursors = true,
  },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. cursorSettings.theme)
  hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. cursorSettings.size)
  hl.exec_cmd("hyprctl setcursor " .. cursorSettings.theme .. " " .. cursorSettings.size)
end)
