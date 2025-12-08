import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { osd, brightnessState, brightnessIcon } from "../services/brightnessosd.service";
import Icon from "../../../components/Icon";

const TOTAL_STEPS = 10;

function BrightnessStepBar() {
  const stepIndices = Array.from({ length: TOTAL_STEPS }, (_, i) => i);

  return (
    <box
      orientation={Gtk.Orientation.HORIZONTAL}
      spacing={3}
      halign={Gtk.Align.CENTER}
      cssName="brightness-step-bar"
    >
      {stepIndices.map((index: number) => {
        const stepThreshold = ((index + 1) / TOTAL_STEPS) - 0.001;

        const stepClass = brightnessState((state) => {
          const filled = state.brightness > stepThreshold;
          return filled ? "brightness-step brightness-step-filled" : "brightness-step";
        });

        return (
          <box
            class={stepClass}
            widthRequest={8}
            heightRequest={6}
          />
        );
      })}
    </box>
  );
}

export function BrightnessOSD() {
  const { BOTTOM } = Astal.WindowAnchor;

  return (
    <window
      name="brightness-osd"
      class="brightness-osd-window"
      layer={Astal.Layer.OVERLAY}
      anchor={BOTTOM}
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.END}
      visible={osd.isVisible}
      application={app}
    >
      <box
        class="osd brightness-osd"
        orientation={Gtk.Orientation.VERTICAL}
        heightRequest={150}
        widthRequest={150}
        spacing={12}
        valign={Gtk.Align.CENTER}
        halign={Gtk.Align.CENTER}
      >
        <box orientation={Gtk.Orientation.VERTICAL} vexpand valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER} spacing={21}>
          <Icon
            icon={brightnessIcon((icon) => icon || "display-brightness-symbolic")}
            size={50}
            cssName="osd-icon"
          />
          <BrightnessStepBar />
        </box>
      </box>
    </window>
  );
}

