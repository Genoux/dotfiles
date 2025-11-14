import app from "ags/gtk4/app";
import { Astal, Gtk, Gdk } from "ags/gtk4";
import { Workspaces } from "./workspaces";
import { SystemTray } from "./systemtray";
import { WindowTitle } from "./windowtitle";
import { SystemTemp } from "./systemtemp";
import { Weather } from "./weather";
import { TimeDisplay } from "./timedisplay";
import { BluetoothButton } from "./bluetooth";
import { VolumeButton } from "./volume";
import { NetworkButton } from "./network";
import { KeyboardButton } from "./keyboard";
import { MediaPlayerButton } from "./mediaplayer";
import { SystemMenuButton } from "./systemmenu";
import { BatteryButton } from "./battery";
import { batteryStateAccessor } from "./battery/service";
import { ScreenRecordButton } from "./screenrecord";

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
      <Gtk.Revealer
        revealChild={true}
        transitionType={Gtk.RevealerTransitionType.CROSSFADE}
        transitionDuration={400}
        valign={Gtk.Align.CENTER}
      >
        <centerbox valign={Gtk.Align.CENTER}>
          <box $type="start" spacing={4} halign={Gtk.Align.CENTER} vexpand={false} valign={Gtk.Align.CENTER}>
            <Workspaces />
            <SystemTray />
          </box>
          <box $type="center" valign={Gtk.Align.CENTER} vexpand={false}>
            <WindowTitle />
          </box>
          <box $type="end" spacing={4} halign={Gtk.Align.END} valign={Gtk.Align.CENTER} vexpand={false}>
            <MediaPlayerButton />
            <box spacing={2}>
              <VolumeButton />
              <NetworkButton />
              <BluetoothButton />
              <ScreenRecordButton />
              <KeyboardButton />
              <BatteryButton />
              <Weather />
              <SystemTemp />
              <TimeDisplay />
              <SystemMenuButton />
            </box>
          </box>
        </centerbox>
      </Gtk.Revealer>
    </window>
  );
}
