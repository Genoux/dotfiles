import { Gtk } from "ags/gtk4";
import {
  getActivePlayer,
  currentPlayerInfo,
  currentPlayerPlayIcon,
  toggleMediaPanel,
} from "../service";
import { CavaVisualizer } from "../../cava";
import { truncateText } from "../../../utils";
import { Button } from "../../../lib/components";

export function MediaPlayerButton({ class: cls = "" }: { class?: string }) {
  return (
    <box spacing={1} class={`mediaplayer ${cls}`} visible={currentPlayerInfo((info) => info !== "No media")}>
      <Button onClicked={toggleMediaPanel}>
        <box spacing={6}>
          <CavaVisualizer />
          <label
            class="media-info"
            label={currentPlayerInfo((info) => truncateText(info, 20).toLowerCase())}
            justify={Gtk.Justification.CENTER}
          />
        </box>
      </Button>

      <box $type="end">
        <Button
          class="media-control"
          onClicked={() => {
            const player = getActivePlayer();
            if (player) {
              player.previous();
            }
          }}
        >
          <image iconName="media-skip-backward-symbolic" pixelSize={10} />
        </Button>
        <Button
          class="media-control play-pause"
          onClicked={() => {
            const player = getActivePlayer();
            if (player) {
              player.play_pause();
            }
          }}
        >
          <image
            iconName={currentPlayerPlayIcon((icon) =>
              icon === "▶" ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
            )}
            pixelSize={10}
          />
        </Button>
        <Button
          class="media-control"
          onClicked={() => {
            const player = getActivePlayer();
            if (player) {
              player.next();
            }
          }}
        >
          <image iconName="media-skip-forward-symbolic" pixelSize={10} />
        </Button>
      </box>
    </box>
  );
}
