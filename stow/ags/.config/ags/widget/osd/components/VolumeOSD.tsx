import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { osd, volumeState, volumeIcon } from "../services/volumeosd.service";
import Icon from "../../../components/Icon";

const TOTAL_STEPS = 10; // 10 steps for 10% increments (0%, 10%, 20%, ..., 100%)

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
                // Each step represents 10%: step 0 = 0-10%, step 1 = 10-20%, ..., step 9 = 90-100%
                // Use a small epsilon to handle floating point precision when comparing
                const stepThreshold = ((index + 1) / TOTAL_STEPS) - 0.001;

                const stepClass = volumeState((state) => {
                    if (state.muted) return "volume-step";

                    // Fill step if volume is above the threshold (with small epsilon for precision)
                    // This ensures accurate 10% step display: 0.9 shows 9 bars, 1.0 shows 10 bars
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
        >
            <box
                class='osd volume-osd'
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
                        size={40}
                        cssName="osd-icon"
                    />
                    <VolumeStepBar />
                </box>
            </box>
        </window>
    );
}