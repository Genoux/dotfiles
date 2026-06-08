local M = {}

local function closeVisibleSpecialWorkspaces()
  for _, monitor in ipairs(hl.get_monitors()) do
    local specialWorkspace = monitor.active_special_workspace
    if specialWorkspace ~= nil then
      local specialName = specialWorkspace.name:gsub("^special:", "")
      if specialName == "special" then
        hl.dispatch(hl.dsp.workspace.toggle_special())
      else
        hl.dispatch(hl.dsp.workspace.toggle_special(specialName))
      end
    end
  end
end

function M.closeVisibleSpecial()
  closeVisibleSpecialWorkspaces()
end

function M.focus(workspace)
  hl.dispatch(hl.dsp.focus({ workspace = workspace }))
end

function M.switch(workspace)
  M.focus(workspace)
  closeVisibleSpecialWorkspaces()
end

return M
