import { Gtk } from "ags/gtk4";
import { createPoll } from "ags/time";
import {
  getActivePlayer,
  currentPlayerInfo,
  currentPlayerPlayIcon,
  toggleMediaPanel,
} from "../service";
import { CavaVisualizer } from "../../cava";
import { Button } from "../../../lib/components";

const MAX_LENGTH = 30;
let scrollPos = 0;
let lastText = "";

const scrollingText = createPoll("", 400, () => {
  const player = getActivePlayer();
  if (!player) return "no media";

  const title = player.title || "Unknown";
  const artist = player.artist || "Unknown Artist";
  const info = `${title} - ${artist}`.toLowerCase();

  if (info !== lastText) {
    scrollPos = 0;
    lastText = info;
  }

  if (info.length <= MAX_LENGTH) {
    return info;
  }

  const paddedText = info + " • ";
  scrollPos = (scrollPos + 1) % paddedText.length;

  const result = paddedText.slice(scrollPos) + paddedText.slice(0, scrollPos);
  return result.slice(0, MAX_LENGTH);
});

export function MediaPlayerButton({ class: cls = "" }: { class?: string }) {
  return (
    <box spacing={1} class={`mediaplayer ${cls}`} visible={currentPlayerInfo((info) => info !== "No media")}>
      <Button onClicked={toggleMediaPanel}>
        <box spacing={6}>
          <CavaVisualizer />
          <label
            class="media-info"
            label={scrollingText((text) => text)}
            justify={Gtk.Justification.LEFT}
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
