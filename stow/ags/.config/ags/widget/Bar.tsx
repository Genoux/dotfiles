import { App, Astal, Gtk, Gdk } from "astal/gtk3";
import { bind } from "astal/binding";
import { Workspaces } from "./workspaces";
import { WindowTitle } from "./windowtitle";
import { KeyboardSwitcher } from "./keyboardswitcher";
import { TimeDisplay } from "./timedisplay";
import { WeatherDisplay } from "./weather";
import { AudioButton } from "./audiocontrols";
import { ControlPanelButton } from "./controlpanel";
import { NotificationButton } from "./notifications";
import { SystemTray, trayItems } from "./systemtray";
import { CavaVisualizer, isPlaying } from "./cava";

function ControlPanelSection() {
  return (
    <ControlPanelButton />
  );
}

function LeftSection() {
  return (
    <>
      <box className="bar-section" halign={Gtk.Align.START} spacing={4}>
        <Workspaces />
      </box>
      <SystemTraySection />
    </>

  );
}

function CenterSection() {
  return (
    <box className="bar-section" halign={Gtk.Align.CENTER} spacing={12}>
      <WindowTitle />
    </box>
  );
}

function CavaSection() {
  return (
    <box className="bar-section" halign={Gtk.Align.END}>
      <CavaVisualizer />
    </box>
  );
}

function SystemTraySection() {
  return (
    <box className="bar-section" halign={Gtk.Align.END} visible={bind(trayItems).as(items => items.length > 0)}>
      <SystemTray />
    </box>
  );
}

function WeatherSection() {
  return (
    <box className="bar-section" halign={Gtk.Align.END} spacing={4}>
      <WeatherDisplay />
    </box>
  );
}

function RightSection() {
  return (
    <box className="bar-section" halign={Gtk.Align.END} spacing={4}>
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
      marginLeft={8}
      marginRight={8}
      marginTop={6}
      marginBottom={6}
      application={App}
    >
      <box className="bar-container" halign={Gtk.Align.FILL} spacing={4}>
        <ControlPanelSection />
        <LeftSection />
        <box halign={Gtk.Align.CENTER} hexpand>
          <CenterSection />
        </box>
        <box halign={Gtk.Align.END} spacing={4}>
          <CavaSection />
          <WeatherSection />
          <RightSection />
        </box>
      </box>
    </window>
  );
}