import app from "ags/gtk4/app";
import { Astal, Gtk, Gdk } from "ags/gtk4";
import { Workspaces } from "./workspaces";
import { SystemTray } from "./systemtray";
import { WindowTitle } from "./windowtitle";
import { CavaVisualizer } from "./cava";
import { SystemTemp } from "./systemtemp";
import { Weather } from "./weather";
import { TimeDisplay } from "./timedisplay";
import { BluetoothButton } from "./bluetooth";
import { NotificationPanelButton } from "./notificationpanel";
import { VolumeButton } from "./volume";
import { InternetButton } from "./internet";
import { KeyboardButton } from "./keyboard";
import { MediaPlayerButton } from "./mediaplayer";

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
      <centerbox>
        <box $type="start">
          <Workspaces />
          <SystemTray />
        </box>
        <box $type="center" spacing={6} valign={Gtk.Align.CENTER}>
          <WindowTitle />
        </box>
        <box $type="end" spacing={3} halign={Gtk.Align.END}>
          <MediaPlayerButton />
          <VolumeButton />
          <InternetButton />
          <BluetoothButton />
          <KeyboardButton />
          <Weather />
          <SystemTemp />
          <TimeDisplay />
          <NotificationPanelButton />
        </box>
      </centerbox>
    </window>
  );
}
