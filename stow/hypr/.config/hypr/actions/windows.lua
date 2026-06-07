local M = {}

function M.groupAwareMove(direction)
  return hl.dsp.window.move({ direction = direction, group_aware = true })
end

function M.cycleWindowState()
  local window = hl.get_active_window()
  if window == nil then
    return
  end

  if window.fullscreen > 0 then
    hl.dispatch(hl.dsp.window.fullscreen({ action = "toggle" }))
    return
  end

  if window.floating then
    hl.dispatch(hl.dsp.window.fullscreen())
    return
  end

  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
end

return M
