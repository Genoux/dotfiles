import { Gtk } from "ags/gtk4";
import { With, createBinding } from "ags";
import Mpris from "gi://AstalMpris";
import Hyprland from "gi://AstalHyprland";
import { players } from "../service";

// Minimal now-playing panel using Astal MPRIS
export function MediaPanel({ class: cls = "" }: { class?: string } = {}) {
  return (
    <With value={players}>
      {(list: Mpris.Player[] | undefined) => {
        const player =
          (list || []).find(
            (p) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING
          ) || list?.[0];
        if (!player) return <box class={`media ${cls}`} visible={false} />;

        const status = createBinding(player, "playbackStatus");
        const canPrev = createBinding(player, "canGoPrevious");
        const canNext = createBinding(player, "canGoNext");
        const canControl = createBinding(player, "canControl");
        const title = createBinding(player, "title");
        const artist = createBinding(player, "artist");
        const album = createBinding(player, "album");
        const cover = createBinding(player, "coverArt");
        const length = createBinding(player, "length");
        const position = createBinding(player, "position");

        return (
          <box class={`media-panel ${cls}`} spacing={8} marginEnd={8} widthRequest={300}>
            <With value={cover}>
              {(c?: string) => (
                <box
                  halign={Gtk.Align.START}
                  valign={Gtk.Align.CENTER}
                  widthRequest={64}
                  heightRequest={64}
                >
                  {c ? (
                    <image
                      file={c.startsWith("file://") ? c.slice(7) : c}
                      halign={Gtk.Align.FILL}    // Fill the box width
                      valign={Gtk.Align.FILL}    // Fill the box height
                      hexpand={true}             // Expand horizontally
                      vexpand={true}             // Expand vertically
                    />
                  ) : (
                    <image iconName={player.entry} pixelSize={28} />
                  )}
                </box>
              )}
            </With>

            <box
              spacing={6}
              orientation={Gtk.Orientation.VERTICAL}
              valign={Gtk.Align.CENTER}
              halign={Gtk.Align.FILL}
            >
             <box spacing={2} orientation={Gtk.Orientation.VERTICAL}>
             <button
                class="media-title-btn"
                onClicked={() => {
                  try {
                    const hypr = Hyprland.get_default();
                    hypr.dispatch("focuswindow", `class:${player.entry}`);
                  } catch (e) {
                    print("focus failed", String(e));
                  }
                }}
              >
                <label
                  class="media-panel__track-title"
                  xalign={0.0}
                  ellipsize={3}
                  maxWidthChars={28}
                  label={title}
                />
              </button>
             <With value={album}>
              {(a) => (
                <label
                  class="media-panel__track-artist"
                  xalign={0.0}
                  ellipsize={3}
                  maxWidthChars={28}
                  label={a || artist}
                />
              )}
             </With>
             </box>
             
              <box halign={Gtk.Align.START} class="media-panel__controls" visible={false}>
                <button sensitive={canPrev} onClicked={() => player.previous()}>
                  <image iconName="media-skip-backward-symbolic" />
                </button>
                <button
                  sensitive={canControl}
                  onClicked={() => player.play_pause()}
                >
                  <With value={status}>
                    {(s: Mpris.PlaybackStatus) => (
                      <image
                        iconName={
                          s === Mpris.PlaybackStatus.PLAYING
                            ? "media-playback-pause-symbolic"
                            : "media-playback-start-symbolic"
                        }
                      />
                    )}
                  </With>
                </button>
                <button sensitive={canNext} onClicked={() => player.next()}>
                  <image iconName="media-skip-forward-symbolic" />
                </button>
              </box>
            </box>
          </box>
        );
      }}
    </With>
  );
}
