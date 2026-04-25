import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import Gtk4LayerShell from "gi://Gtk4LayerShell";
import { osd, volumeState, volumeIcon } from "../services/volumeosd.service";
import Icon from "../../../components/Icon";

const TOTAL_STEPS = 10;

function VolumeStepBar() {
    const stepIndices = Array.from({ length: TOTAL_STEPS }, (_, i) => i);

    return (
        <box
            orientation={Gtk.Orientation.HORIZONTAL}
            spacing={3}
            halign={Gtk.Align.CENTER}
            cssName="volume-step-bar"
        >
            {stepIndices.map((index: number) => {
                const stepThreshold = ((index + 1) / TOTAL_STEPS) - 0.001;

                const stepClass = volumeState((state) => {
                    if (state.muted) return "volume-step";
                    const filled = state.volume > stepThreshold;
                    return filled ? "volume-step volume-step-filled" : "volume-step";
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

export function VolumeOSD() {
    const { BOTTOM } = Astal.WindowAnchor;

    return (
        <window
            name="osd"
            class="volume-osd-window"
            layer={Astal.Layer.OVERLAY}
            anchor={BOTTOM}
            halign={Gtk.Align.CENTER}
            valign={Gtk.Align.END}
            visible={osd.isVisible}
            application={app}
            $={(self) => Gtk4LayerShell.set_namespace(self, "osd")}
        >
            <box
                class="osd volume-osd"
                orientation={Gtk.Orientation.VERTICAL}
                heightRequest={150}
                widthRequest={150}
                spacing={12}
                valign={Gtk.Align.CENTER}
                halign={Gtk.Align.CENTER}
            >
                <box orientation={Gtk.Orientation.VERTICAL} vexpand valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER} spacing={21}>
                    <Icon
                        icon={volumeIcon((icon) => icon || "audio-volume-medium-symbolic")}
                        size={50}
                        cssName="osd-icon"
                    />
                    <VolumeStepBar />
                </box>
            </box>
        </window>
    );
}
