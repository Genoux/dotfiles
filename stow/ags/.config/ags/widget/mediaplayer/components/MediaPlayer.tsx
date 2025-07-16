import { Astal, Gtk } from "astal/gtk3";
import Mpris from "gi://AstalMpris";
import { bind, Variable } from "astal";
import Hyprland from "gi://AstalHyprland"
import { toggleControlPanel } from "../../controlpanel/Service"

import {
  trackPlayerInteraction,
  setupPlaybackMonitoring,
  getMostRecentPlayer,
  globalUpdateTrigger,
  lengthStr,
} from "../Service";


// Pure UI Components
export function TrackInfo({ player }: { player: Mpris.Player }) {
  const { START } = Gtk.Align;

  const title = bind(player, "title").as((t) => t || "Unknown Track");
  const artist = bind(player, "artist").as((a) => a || "Unknown Artist");

  const playerIcon = bind(player, "entry").as((e) =>
    Astal.Icon.lookup_icon(e) ? e : "audio-x-generic-symbolic"
  );

  return (
    <box className="track-info" vertical>
      <box className="title-row">
        <label
          className="track-title"
          halign={START}
          hexpand
          label={title}
          truncate={false}
          ellipsize={3} // PANGO_ELLIPSIZE_END
        />
        <box className="player-indicator">
          <icon icon={playerIcon} />
        </box>
      </box>
      <label
        className="track-artist"
        halign={START}
        label={artist}
        ellipsize={3} // PANGO_ELLIPSIZE_END
      />
    </box>
  );
}

export function ProgressWithTime({
  player,
  trackPlayerInteraction,
}: {
  player: Mpris.Player;
  trackPlayerInteraction: (player: Mpris.Player) => void;
}) {
  // UI state
  const position = Variable(0); // 0-1 range
  const currentTime = Variable(0); // actual seconds

  let isUserInteracting = false;
  let positionHandler: number | null = null;
  let statusHandler: number | null = null;
  let lastKnownPosition = 0;

  // Connect to player notifications
  function connectToPlayer() {
    if (positionHandler) return; // Already connected

    positionHandler = player.connect("notify::position", () => {
      if (
        !isUserInteracting &&
        player.playbackStatus === Mpris.PlaybackStatus.PLAYING &&
        player.length > 0
      ) {
        const playerPos = player.position / player.length;
        position.set(playerPos);
        currentTime.set(player.position);
        lastKnownPosition = player.position;
      }
    });

    statusHandler = player.connect("notify::playback-status", () => {
      if (!isUserInteracting && player.length > 0) {
        const playerPos = player.position / player.length;
        position.set(playerPos);
        currentTime.set(player.position);
        lastKnownPosition = player.position;
      }
    });
  }

  // Disconnect from player notifications
  function disconnectFromPlayer() {
    if (positionHandler) {
      player.disconnect(positionHandler);
      positionHandler = null;
    }
    if (statusHandler) {
      player.disconnect(statusHandler);
      statusHandler = null;
    }
  }

  // Initialize
  if (player.length > 0) {
    const playerPos = player.position / player.length;
    position.set(playerPos);
    currentTime.set(player.position);
    lastKnownPosition = player.position;
  }
  connectToPlayer();
  return (
    <box className="progress-with-time" spacing={8} halign={Gtk.Align.FILL} hexpand>
      <label
        className="current-time"
        visible={bind(player, "length").as((l) => l > 0)}
        label={bind(currentTime).as(lengthStr)}
        halign={Gtk.Align.END}
      />
      <slider
        className="MediaPlayer__progress-scale"
        hexpand
        visible={bind(player, "length").as((l) => l > 0)}
        value={bind(position)}
        onButtonPressEvent={() => {
          isUserInteracting = true;
          disconnectFromPlayer(); // Completely stop listening to player
          return false;
        }}
        onDragged={({ value }) => {
          // User dragging - only update local UI
          position.set(value);
          currentTime.set(value * player.length);
        }}
        onButtonReleaseEvent={() => {
          // Get the target seek time and seek immediately
          const seekTime = position.get() * player.length;
          player.position = seekTime;
          trackPlayerInteraction(player);

          // Keep the UI locked at user position until seek completes
          // Don't reconnect to player notifications immediately
          setTimeout(() => {
            isUserInteracting = false;
            connectToPlayer();
          }, 800); // Give enough time for seek to complete

          return false;
        }}
      />
      <label
        className="total-time"
        visible={bind(player, "length").as((l) => l > 0)}
        label={bind(player, "length").as((l) =>
          l > 0 ? lengthStr(l) : "0:00"
        )}
        halign={Gtk.Align.START}
        ellipsize={0} // PANGO_ELLIPSIZE_NONE - don't ellipsize time
        maxWidthChars={5} // Max chars for "99:99"
      />
    </box>
  );
}

export function MediaControls({
  player,
  trackPlayerInteraction,
}: {
  player: Mpris.Player;
  trackPlayerInteraction: (player: Mpris.Player) => void;
}) {
  const playIcon = bind(player, "playbackStatus").as((s) =>
    s === Mpris.PlaybackStatus.PLAYING
      ? "media-playback-pause-symbolic"
      : "media-playback-start-symbolic"
  );

  return (
    <box className="controls" halign={Gtk.Align.CENTER} hexpand spacing={12}>
      <button
        className="control-btn prev-btn"
        halign={Gtk.Align.START}
        onClicked={() => {
          player.previous();
          trackPlayerInteraction(player);
        }}
        visible={bind(player, "canGoPrevious")}
      >
        <icon icon="media-skip-backward-symbolic" />
      </button>
      <button
        className="control-btn play-btn"
        halign={Gtk.Align.CENTER}
        onClicked={() => {
          player.play_pause();
          trackPlayerInteraction(player);
        }}
        visible={bind(player, "canControl")}
      >
        <icon icon={playIcon} />
      </button>
      <button
        className="control-btn next-btn"
        halign={Gtk.Align.END}
        onClicked={() => {
          player.next();
          trackPlayerInteraction(player);
        }}
        visible={bind(player, "canGoNext")}
      >
        <icon icon="media-skip-forward-symbolic" />
      </button>
    </box>
  );
}

// MediaPlayer component that can be used in JSX
export default function MediaPlayer() {
  const mpris = Mpris.get_default();
  const hypr = Hyprland.get_default();

  // Set up monitoring for player list changes
  mpris.connect("notify::players", () => {
    globalUpdateTrigger.set(globalUpdateTrigger.get() + 1);
    setupPlaybackMonitoring(mpris.players);
  });

  // Initial setup
  setupPlaybackMonitoring(mpris.players);

  return (
    <box vertical className="MediaPlayerContainer">
      {bind(globalUpdateTrigger).as(() => {
        const players = mpris.players;
        const activePlayer = getMostRecentPlayer(players);

        if (players.length === 0 || !activePlayer) {
          return null; // Return null when no player
        }

        const coverArtBackground = bind(activePlayer, "coverArt").as((c) => 
          c ? `background-image: linear-gradient(rgba(0, 0, 0, 0.6), rgba(0, 0, 0, 0.7)), url('${c}'); background-size: cover, 110%; background-position: center, center;` : ""
        );

        return (
          <eventbox
            onButtonPressEvent={() => {
              const appClass = activePlayer.entry;
              try {
                hypr.dispatch("focuswindow", `class:${appClass}`);
                toggleControlPanel();
              } catch (error) {
                console.error("No app class found for player", error);
              }
            }}
          >
          <box 
            className="MediaPlayer" 
            heightRequest={100} 
            spacing={6}
            css={coverArtBackground} 
          
          >
            <box className="media-content" vertical hexpand spacing={6}>
              <TrackInfo player={activePlayer} />
              <ProgressWithTime
                player={activePlayer}
                trackPlayerInteraction={trackPlayerInteraction}
              />
              <MediaControls
                player={activePlayer}
                trackPlayerInteraction={trackPlayerInteraction}
              />
            </box>
          </box>
          </eventbox>
        );
      })}
    </box>
  );
}
