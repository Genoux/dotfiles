import Mpris from "gi://AstalMpris";
import { createBinding, createState } from "ags";
import Hyprland from "gi://AstalHyprland";

// Astal MPRIS service
const mpris = Mpris.get_default();

// Reactive list of players
export const players = createBinding(mpris, "players");

// Export the raw service in case components need direct access
export const mprisService = mpris;

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
  // __mediaVisible = !__mediaVisible;
  // print(`[MediaPanel] toggle -> ${__mediaVisible ? "true" : "false"}`);
  // setMediaPanelVisible(__mediaVisible);
}