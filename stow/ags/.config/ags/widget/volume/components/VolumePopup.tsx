import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { volumePanelVisible, hideVolumePanel } from "../service";
import { VolumePanel } from "./VolumePanel";

// Top-level window that hosts the volume panel content
export function VolumePopup() {
  return (
    <window
      name="popup-window"
      class="volume-popup"
      application={app}
      visible={volumePanelVisible}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.NONE}
      exclusivity={Astal.Exclusivity.IGNORE}
      marginTop={45}
      onCloseRequest={() => hideVolumePanel()}
      onHide={() => hideVolumePanel()}
    >
      <revealer
        transitionType={Gtk.RevealerTransitionType.NONE}
        revealChild={volumePanelVisible}
      >
        <box class="volume-popup__container">
          <VolumePanel />
        </box>
      </revealer>
    </window>
  );
}