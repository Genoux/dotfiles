import { Gtk } from "ags/gtk4";
import { createPoll } from "ags/time";
import Mpris from "gi://AstalMpris";
import {
  getActivePlayer,
  currentPlayerInfo,
  currentPlayerPlayIcon,
  toggleMediaPanel,
} from "../service";
import { CavaVisualizer } from "../../cava";
import { Button } from "../../../lib/components";

const MAX_LENGTH = 30;
const SCROLL_SPEED = 400;

let scrollOffset = 0;

const scrollingText = createPoll("", SCROLL_SPEED, () => {
  const text = currentPlayerInfo.get();

  if (text.length <= MAX_LENGTH) {
    scrollOffset = 0;
    return text;
  }

  const paddedText = text + " • ";
  const scrolled = paddedText.slice(scrollOffset) + paddedText.slice(0, scrollOffset);

  scrollOffset = (scrollOffset + 1) % paddedText.length;
  return scrolled.slice(0, MAX_LENGTH);
});

export function MediaPlayerButton({ class: cls = "" }: { class?: string }) {

  return (
    <box spacing={1} class={`mediaplayer ${cls}`} visible={currentPlayerInfo((info) => info !== "No media")}>
      <Button onClicked={toggleMediaPanel}>
        <box
          spacing={6}
          class="media-content"
        >
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
