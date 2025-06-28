import { App, Astal, Gtk, Gdk } from "astal/gtk3";
import { bind } from "astal/binding";
import { Workspaces } from "./workspaces";
import { WindowTitle } from "./windowtitle";
import { KeyboardSwitcher } from "./keyboardswitcher";
import { TimeDisplay } from "./timedisplay";
import { WeatherDisplay } from "./weather";
import { SystemTempDisplay } from "./systemtemp";
import { BatteryDisplay, batteryVisible } from "./battery";
import { AudioButton } from "./audiocontrols";
import { ControlPanelButton } from "./controlpanel";
import { NotificationButton } from "./notifications";
import { SystemTray, trayItems } from "./systemtray";
import { CavaVisualizer, isPlaying } from "./cava";
import { windowManager } from "./utils";

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
    <box className="bar-section">
      <WindowTitle />
    </box>
  );
}

function CavaSection() {
  return (
    <box className="bar-section">
      <CavaVisualizer />
    </box>
  );
}

function SystemTraySection() {
  return (
    <box className="bar-section" visible={bind(trayItems).as(items => items.length > 0)}>
      <SystemTray />
    </box>
  );
}

function WeatherSection() {
  return (
    <box className="bar-section" spacing={4}>
      <WeatherDisplay />
    </box>
  );
}

function SystemTempSection() {
  return (
    <box className="bar-section" halign={Gtk.Align.END} spacing={4}>
      <SystemTempDisplay />
    </box>
  );
}

function BatterySection() {
  return (
    <box 
      className="bar-section" 
      spacing={4}
      visible={batteryVisible}
    >
      <BatteryDisplay />
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
      marginTop={0}
      marginBottom={6}
      application={App}
      onButtonPressEvent={() => {
        windowManager.hide("*")
      }}
    >
      <box className="bar-container" hexpand homogeneous>
        <box halign={Gtk.Align.START} spacing={4}>
          <ControlPanelSection />
          <LeftSection />
        </box>
        <box halign={Gtk.Align.CENTER}>
          <CenterSection />
        </box>
        <box halign={Gtk.Align.END} spacing={4}>
          <CavaSection />
          <SystemTempSection />
          <BatterySection />
          <WeatherSection />
          <RightSection />
        </box>
      </box>
    </window>
  );
}