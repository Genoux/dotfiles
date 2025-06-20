import { Astal } from "astal/gtk3"
import { createWindow, windowManager } from "../utils"
import ControlPanel from "./components/ControlPanel"

// Create popup window with auto-close behavior
export const controlPanel = createWindow({
  name: "control-panel",
  className: "control-panel-window",
  content: ControlPanel(),
  anchor: Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.LEFT,
  autoClose: true,
})

export const controlPanelVisible = controlPanel.isVisible
export const toggleControlPanel = controlPanel.toggle
