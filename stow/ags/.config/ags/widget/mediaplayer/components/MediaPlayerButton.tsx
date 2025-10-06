import { Gtk } from "ags/gtk4";
import { getActivePlayer, currentPlayerInfo, currentPlayerPlayIcon } from "../service";

export function MediaPlayerButton({
  class: cls = "",
}: {
  class?: string;
}) {

  return (
    <box
      class={`mediaplayer ${cls}`}
      spacing={6}
      visible={currentPlayerInfo((info) => info !== "No media")}
    >

      <label
        class="media-info"
        label={currentPlayerInfo((info) => info)}
        widthChars={20}
        maxWidthChars={30}
        ellipsize={3}
        wrap={true}
        halign={Gtk.Align.END}
        justify={Gtk.Justification.RIGHT}
      />
      <box>
        <button
          class="media-control"
          onClicked={() => {
            const player = getActivePlayer();
            if (player) {
              player.previous();
            }
          }}
        >
          <image
            iconName="media-skip-backward-symbolic"
            pixelSize={11}
          />
        </button>
        <button
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
            pixelSize={11}
          />
        </button>
        <button
          class="media-control"
          onClicked={() => {
            const player = getActivePlayer();
            if (player) {
              player.next();
            }
          }}
        >
          <image
            iconName="media-skip-forward-symbolic"
            pixelSize={11}
          />
        </button>
      </box>
    </box>
  );
}