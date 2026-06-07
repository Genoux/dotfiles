local gapProfiles = {
  solo = { gaps_in = 2, gaps_out = 16 },
  normal = { gaps_in = 2, gaps_out = 8 },
  dense = { gaps_in = 1, gaps_out = 4 },
  special = { gaps_in = 0, gaps_out = 12 },
}

local function specialWorkspaceOpen()
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.active_special_workspace ~= nil then
      return true
    end
  end
  return false
end

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
  if specialWorkspaceOpen() then
    hl.config({ general = gapProfiles.special })
    return
  end

  local workspace = hl.get_active_workspace()
  local tiledCount = tiledWindowCount(workspace)
  local profile = gapProfiles.normal

  if tiledCount <= 1 then
    profile = gapProfiles.solo
  elseif tiledCount >= 4 then
    profile = gapProfiles.dense
  end

  hl.config({ general = profile })
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
