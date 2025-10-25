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
      <Gtk.Revealer
        revealChild={true}
        transitionType={Gtk.RevealerTransitionType.CROSSFADE}
        transitionDuration={400}
      >
        <centerbox>
          <box $type="start">
            <Workspaces />
            <SystemTray />
          </box>
          <box $type="center" spacing={6} valign={Gtk.Align.CENTER}>
            <WindowTitle />
          </box>
          <box $type="end" spacing={4} halign={Gtk.Align.END}>
            <MediaPlayerButton />
            <VolumeButton />
            <InternetButton />
            <BluetoothButton />
            <KeyboardButton />
            <Weather />
            <SystemTemp />
            <TimeDisplay />
          </box>
        </centerbox>
      </Gtk.Revealer>
    </window>
  );
}
