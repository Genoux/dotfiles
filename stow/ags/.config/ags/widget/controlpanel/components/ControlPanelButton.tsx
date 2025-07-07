import { bind } from "astal"
import { controlPanelVisible, toggleControlPanel } from "../Service"

export default function ControlPanelButton() {
  return (
    <button
      widthRequest={42}
      heightRequest={20}
      className={bind(controlPanelVisible).as(visible => 
        `control-panel-button ${visible ? 'active' : ''}`
      )}
      onClicked={toggleControlPanel}
    >
        <icon icon="document-properties-symbolic" />
    </button>
  )
} 