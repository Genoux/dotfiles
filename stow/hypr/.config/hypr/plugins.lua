if hl.plugin.hyprexpo ~= nil then
  package.loaded["config.workspaces"] = nil
  local workspaceConfig = require("config.workspaces")
  local columns = math.max(2, math.min(5, math.ceil(workspaceConfig.workspace_count / 3)))

  hl.config({
    plugin = {
      hyprexpo = {
        columns = columns,
        workspace_method = "center current",
      },
    },
  })
end
