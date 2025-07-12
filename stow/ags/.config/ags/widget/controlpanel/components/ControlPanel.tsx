import { bind } from "astal"
import { MediaPlayer, hasMediaPlayers } from "../../mediaplayer"
import AudioControls from "../../audiocontrols"
import { NotificationCenterWidget } from "../../notifications"
import { SystemControl } from "../../systemcontrol"

export default function ControlPanel() {
  return (
    <box className="control-panel" vertical spacing={6} hexpand
    >
      <box className="notification-section">
        <NotificationCenterWidget />
      </box>
      <box className="widget">
        <SystemControl />
      </box>
      <box className="widget">
        <AudioControls />
      </box>
      <box visible={bind(hasMediaPlayers).as((visible) => visible)}>
        <MediaPlayer />
      </box>
    </box>
  )
} 