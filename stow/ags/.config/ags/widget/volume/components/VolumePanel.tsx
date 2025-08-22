import Wp from "gi://AstalWp";
import { createBinding, createState } from "ags";
import { Gtk } from "ags/gtk4";

function getVolumeIcon(volume: number, muted: boolean): string {
  if (muted) return "audio-volume-muted-symbolic";
  if (volume > 0.6) return "audio-volume-high-symbolic";
  if (volume > 0.3) return "audio-volume-medium-symbolic";
  if (volume > 0) return "audio-volume-low-symbolic";
  return "audio-volume-low-symbolic";
}

function clampVolume(volume: number): number {
  return Math.min(Math.max(volume, 0), 1.0);
}

export function VolumePanel({ class: cls = "" }: { class?: string } = {}) {
  const audio = Wp.get_default();
  
  if (!audio) {
    return (
      <box class={`volume-panel ${cls}`}>
        <label label="No audio system" />
      </box>
    );
  }
  
  const speaker = audio.get_default_speaker();
  
  if (!speaker) {
    return (
      <box class={`volume-panel ${cls}`}>
        <label label="No audio device" />
      </box>
    );
  }

  const volume = createBinding(speaker, "volume");
  const muted = createBinding(speaker, "mute");
  const [uiVolume, setUiVolume] = createState(clampVolume(speaker.volume));
  const [uiIcon, setUiIcon] = createState(
    getVolumeIcon(clampVolume(speaker.volume), speaker.mute)
  );

  return (
    <box class={`volume-panel ${cls}`} spacing={12}>
      {/* Volume icon - click to mute/unmute */}
      <button 
        class="volume-panel__mute-button"
        onClicked={() => {
          speaker.mute = !speaker.mute;
          setUiIcon(getVolumeIcon(clampVolume(speaker.volume), speaker.mute));
        }}
      >
        <image
          iconName={uiIcon}
          pixelSize={20}
        />
      </button>

      {/* Simple thin slider (interactive Gtk.Scale) */}
      {(() => {
        const adj = new Gtk.Adjustment({
          lower: 0,
          upper: 1,
          step_increment: 0.01,
          page_increment: 0.1,
          page_size: 0,
          value: speaker.volume,
        });

        const scale = new Gtk.Scale({
          orientation: Gtk.Orientation.HORIZONTAL,
          draw_value: false,
          adjustment: adj,
          hexpand: true,
        });

        scale.add_css_class("volume-panel__slider");
        // snap knob exactly to pointer position on click
        const click = new Gtk.GestureClick();
        click.connect("pressed", (_n: number, x: number) => {
          const width = scale.get_allocated_width();
          if (width > 0) {
            const frac = Math.min(1, Math.max(0, x / width));
            const v = Math.round(frac * 100) / 100; // align to 0.01 step
            adj.set_value(v);
            setUiVolume(v);
            if (speaker.volume !== v) speaker.volume = v;
          }
        });
        scale.add_controller(click);

        let updatingFromSystem = false;

        // user -> system + immediate UI
        scale.connect("value-changed", () => {
          if (updatingFromSystem) return;
          const v = Math.min(1, Math.max(0, scale.get_value()));
          setUiVolume(v); // instant label/icon
          setUiIcon(getVolumeIcon(v, speaker.mute));
          if (speaker.volume !== v) speaker.volume = v;
        });

        // system -> ui (external changes)
        volume((v: number) => {
          updatingFromSystem = true;
          setUiVolume(v);
          setUiIcon(getVolumeIcon(v, speaker.mute));
          if (Math.abs(scale.get_value() - v) > 0.001) scale.set_value(v);
          updatingFromSystem = false;
          return v;
        });

        return scale;
      })()}

      {/* Volume value */}
      <label
        class="volume-panel__value"
        label={uiVolume((vol: number) => `${Math.round(clampVolume(vol) * 100)}%`)}
      />
    </box>
  );
}