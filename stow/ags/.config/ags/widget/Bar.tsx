import { App, Astal, Gtk, Gdk } from "astal/gtk3";
import { bind } from "astal/binding";
import { Workspaces } from "./workspaces";
import { WindowTitle } from "./windowtitle";
import { KeyboardSwitcher } from "./keyboardswitcher";
import { TimeDisplay } from "./timedisplay";
import { AudioButton } from "./audiocontrols";
import { ControlPanelButton } from "./controlpanel";
import { NotificationButton } from "./notifications";
import { SystemTray, trayItems } from "./systemtray";

import { closeAllWindows } from "./utils/WindowHelper"


function LeftSection() {
  return (
    <box className="bar-section bar-left" halign={Gtk.Align.START} spacing={4}>
      <box className="control-panel-button">
        <ControlPanelButton />
      </box>
      <box className="bar-item workspaces">
        <Workspaces />
      </box>
      <box className="bar-item system-tray" visible={bind(trayItems).as(items => items.length > 0)}>
        <SystemTray />
      </box>
    </box>
  );
}

function CenterSection() {
  return (
    <box className="bar-section bar-center bar-item" halign={Gtk.Align.CENTER}>
      <WindowTitle />
    </box>
  );
}

function RightSection() {
  return (
    <box className="bar-section bar-right bar-item" halign={Gtk.Align.END}>
      <NotificationButton />
      <KeyboardSwitcher />
      <AudioButton />
      <TimeDisplay />
    </box>
  );
}

interface BarProps {
  gdkmonitor: Gdk.Monitor;
}

export default function Bar({ gdkmonitor }: BarProps) {
  const { BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor;

  return (

    <window
      name="Bar"
      className="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={BOTTOM | LEFT | RIGHT}
      layer={Astal.Layer.OVERLAY}
      heightRequest={24}
      marginTop={2}
      marginBottom={2}
      application={App}
    >
      <centerbox className="bar-container">
        <LeftSection />
        <CenterSection />
        <RightSection />
      </centerbox>
    </window>
  );
}