import app from "ags/gtk4/app";
import { Astal, Gtk, Gdk } from "ags/gtk4";
import { createPoll } from "ags/time";
import { Workspaces } from "./workspaces";
import { SystemTray } from "./systemtray";
import { WindowTitle } from "./windowtitle";
import { CavaVisualizer } from "./cava";
import { SystemTemp } from "./systemtemp";
import { Weather } from "./weather";
import { TimeDisplay } from "./timedisplay";
import { BluetoothButton } from "./bluetooth";
import { NotificationPanelButton } from "./notificationpanel";
// MediaPanel window is instantiated globally in app.ts via MediaPopup

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT, BOTTOM } = Astal.WindowAnchor;

  return (
    <window
      visible
      name="bar"
      class="bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={BOTTOM | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox">
        <box $type="start" spacing={3}>
          <Workspaces class="bar-section" />
          <SystemTray class="bar-section" />
        </box>
        <box $type="center" spacing={6}>
          <WindowTitle class="bar-section" />
        </box>
        <box $type="end" spacing={3} halign={Gtk.Align.END}>
          <CavaVisualizer class="bar-section" />
          <Weather class="bar-section" />
          <SystemTemp class="bar-section" />
          <TimeDisplay class="bar-section" />
          <NotificationPanelButton class="bar-section" />
          <BluetoothButton class="bar-section" />
        </box>
      </centerbox>
    </window>
  );
}
