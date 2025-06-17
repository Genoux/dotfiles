import { bind } from "astal"
import { Astal, Gtk } from "astal/gtk3";
import { controlPanelVisible, toggleControlPanel } from "../Service"

export default function ControlPanelButton() {
  return (
    <button
      widthRequest={30}
      className={bind(controlPanelVisible).as(visible => 
        `control-panel-button ${visible ? 'active' : ''}`
      )}
      onClicked={toggleControlPanel}
    >
        <icon icon="document-properties-symbolic" />
    </button>
  )
} 