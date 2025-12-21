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
import Icon from "../../../components/Icon";

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

export function MediaPlayerButton() {

  return (
    <box spacing={3} class='mediaplayer group' visible={currentPlayerInfo((info) => info !== "No media" && info !== "Unknown")}>
      <Button onClicked={toggleMediaPanel}>
        <box
          spacing={6}
          class="media-content"
          vexpand={false}
          valign={Gtk.Align.CENTER}
        >
          <CavaVisualizer />
          <label
            class="media-info"
            label={scrollingText((text) => text)}
            justify={Gtk.Justification.LEFT}
          />
        </box>
      </Button>

      <box $type="end" vexpand={false} valign={Gtk.Align.CENTER}>
        <Button
          class="media-control"
          onClicked={() => {
            const player = getActivePlayer();
            if (player) {
              player.previous();
            }
          }}
        >
          <Icon icon="media-skip-backward-symbolic" pixelSize={13} />
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
          <Icon
            icon={currentPlayerPlayIcon((icon) =>
              icon === "▶" ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
            )}
            pixelSize={13}
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
          <Icon icon="media-skip-forward-symbolic" pixelSize={13} />
        </Button>
      </box>
    </box>
  );
}
