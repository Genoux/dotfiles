import Mpris from "gi://AstalMpris";
import { createBinding, createState } from "ags";
import { createPoll } from "ags/time";
import Hyprland from "gi://AstalHyprland";

// Astal MPRIS service
const mpris = Mpris.get_default();

const POLL_INTERVAL = 200;

// Reactive list of players
export const players = createBinding(mpris, "players");

// Export the raw service in case components need direct access
export const mprisService = mpris;

// Helper function to get the active player
export function getActivePlayer() {
  const playerList = mpris.players;
  return playerList.find((p) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING) || playerList[0];
}

// Poll current player state every POLL_INTERVAL
export const currentPlayerInfo = createPoll(
  "No media",
  POLL_INTERVAL,
  () => {
    try {
      const player = getActivePlayer();
      if (!player) return "No media";
      const title = player.title || "Unknown";
      const artist = player.artist || "Unknown Artist";
      return `${title} - ${artist}`;
    } catch (error) {
      return "No media";
    }
  }
);

export const currentPlayerPlayIcon = createPoll(
  "⏸",
  POLL_INTERVAL,
  () => {
    try {
      const player = getActivePlayer();
      if (!player) return "⏸";
      return player.playbackStatus === Mpris.PlaybackStatus.PLAYING ? "⏸" : "▶";
    } catch (error) {
      return "⏸";
    }
  }
);

// Visibility state for the media panel (toggled by CAVA click)
export const [mediaPanelVisible, setMediaPanelVisible] = createState(false);

const hypr = Hyprland.get_default();

let __mediaVisible = false;
export function showMediaPanel() {
  __mediaVisible = true;
  print(`[MediaPanel] show`);
  setMediaPanelVisible(true);
}

export function hideMediaPanel() {
  __mediaVisible = false;
  print(`[MediaPanel] hide`);
  setMediaPanelVisible(false);
}

export function toggleMediaPanel() {
  const players = mprisService.players;
  const player = players.find((p) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING);
  if (player) {
    hypr.dispatch("focuswindow", `class:${player.entry}`);
  }
}