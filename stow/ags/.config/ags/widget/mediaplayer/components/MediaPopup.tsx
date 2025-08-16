import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { mediaPanelVisible, setMediaPanelVisible } from "../service";
import { MediaPanel } from "./MediaPanel";

// Top-level window that hosts the media panel content
export function MediaPopup() {
  return (
    <window
      name="media-panel"
      class="media-popup"
      application={app}
      visible={mediaPanelVisible}
      anchor={Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
    >
      <revealer
        transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
        revealChild={mediaPanelVisible}
      >
        <box class="media-popup__container">
          <MediaPanel />
        </box>
      </revealer>
    </window>
  );
}
