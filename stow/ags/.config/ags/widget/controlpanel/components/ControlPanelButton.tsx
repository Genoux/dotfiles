import { bind } from "astal"
import { controlPanelVisible, toggleControlPanel } from "../Service"

export default function ControlPanelButton() {
  return (
    <button
      onClicked={toggleControlPanel}
      className={bind(controlPanelVisible).as((visible) => visible ? "active" : "")}
    >
        <icon icon="document-properties-symbolic" />
    </button>
  )
} 