import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { isVisible, volumeState, volumeIcon } from "../service";

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
                const stepValue = (index + 1) / TOTAL_STEPS;

                const stepClass = volumeState((state) => {
                    const filled = !state.muted && state.volume >= stepValue;
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

            visible={isVisible}
            application={app}
        >
            <Gtk.Revealer
                revealChild={isVisible}
                transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
                transitionDuration={300}
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
                        <image
                            iconName={volumeIcon((icon) => icon || "audio-volume-medium-symbolic")}
                            pixelSize={40}
                            cssName="osd-icon"
                            halign={Gtk.Align.CENTER}
                        />
                        <VolumeStepBar />
                    </box>
                </box>
            </Gtk.Revealer>
        </window>
    );
}