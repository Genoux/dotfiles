-- dofile, not require: hyprland.lua only clears its own module list on reload,
-- so a required value would survive an edit.
local spacing = dofile(os.getenv("HOME") .. "/.config/hypr/spacing.lua")

-- Only the gaps between windows adapt to how many there are. The outer gap is
-- the shared spacing, so windows, bar and screen edges stay balanced.
local gapProfiles = {
  solo = { gaps_in = 1 },
  normal = { gaps_in = 2 },
  dense = { gaps_in = 1 },
}

local function tiledWindowCount(workspace)
  if workspace == nil then
    return 0
  end

  local workspaceId = workspace.id
  local count = 0

  for _, window in ipairs(hl.get_windows()) do
    local windowWorkspace = window.workspace
    if windowWorkspace ~= nil
      and windowWorkspace.id == workspaceId
      and not window.floating
      and window.fullscreen == 0
    then
      count = count + 1
    end
  end

  return count
end

local function applySmartGaps()
  local workspace = hl.get_active_workspace()
  local tiledCount = tiledWindowCount(workspace)
  local profile = gapProfiles.normal

  if tiledCount <= 1 then
    profile = gapProfiles.solo
  elseif tiledCount >= 4 then
    profile = gapProfiles.dense
  end

  hl.config({ general = { gaps_in = profile.gaps_in, gaps_out = spacing } })
end

for _, event in ipairs({
  "window.open",
  "window.close",
  "window.active",
  "window.fullscreen",
  "workspace.active",
}) do
  hl.on(event, applySmartGaps)
end

applySmartGaps()
