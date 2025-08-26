import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { volumePanelVisible, hideVolumePanel } from "../service";
import { VolumePanel } from "./VolumePanel";

// Top-level window that hosts the volume panel content
export function VolumePopup() {
  return (
    <window
      name="volume-popup-window"
      class="volume-popup"
      application={app}
      visible={volumePanelVisible}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      onCloseRequest={() => hideVolumePanel()}
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