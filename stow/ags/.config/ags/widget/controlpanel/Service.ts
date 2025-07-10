import { Astal } from "astal/gtk3"
import { windowManager } from "../utils"
import ControlPanel from "./components/ControlPanel"

// Create control panel with the new unified system
export const controlPanel = windowManager.createWindow({
  name: "control-panel",
  type: 'popup',
  className: "control-panel-window",
  content: ControlPanel(),
  anchor: Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT,
  exclusive: true,   // Only one popup at a time
  autoClose: true,   // Close on ESC, fullscreen click (including AGS bar), workspace change
})

export const controlPanelVisible = controlPanel.isVisible
export const toggleControlPanel = controlPanel.toggle
