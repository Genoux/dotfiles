local M = {}

function M.groupAwareMove(direction)
  return hl.dsp.window.move({ direction = direction, group_aware = true })
end

return M
