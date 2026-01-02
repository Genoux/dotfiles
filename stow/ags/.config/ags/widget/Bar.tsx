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
import { ScreenRecordButton } from "./screenrecord";
import { SystemInfoButton } from "./systeminfo";
import { SystemDotfilesButton } from "./systemdotfiles";
import { PrivacyIndicator } from "./privacy";

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
          <box $type="center" valign={Gtk.Align.CENTER} vexpand={false} marginStart={12} marginEnd={12}>
            <WindowTitle />
          </box>
          <box $type="end">
          <box valign={Gtk.Align.CENTER}>
              <PrivacyIndicator />
            </box>
            <box valign={Gtk.Align.CENTER} marginEnd={6}  marginStart={6}>
              <MediaPlayerButton />
            </box>

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
              <SystemInfoButton />
              <SystemDotfilesButton />
              <SystemMenuButton />
            </box>
          </box>
        </centerbox>
      </Gtk.Revealer>
    </window>
  );
}
