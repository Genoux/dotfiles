import Mpris from "gi://AstalMpris";
import { createState } from "ags";
import { hypr } from "./hyprland";

const mpris = Mpris.get_default();

// Use counter to force reactive updates when player state changes
const [updateId, setUpdateId] = createState(0);
const forceUpdate = () => setUpdateId((id) => id + 1);

// Listen to player changes
mpris.connect("notify::players", forceUpdate);

// Track player handlers to prevent duplicate connections
const playerHandlers = new Map<Mpris.Player, number[]>();

const setupPlayerWatchers = () => {
  // Disconnect old handlers
  playerHandlers.forEach((handlers, player) => {
    handlers.forEach((handlerId) => player.disconnect(handlerId));
  });
  playerHandlers.clear();

  // Connect new handlers
  mpris.players.forEach((player: Mpris.Player) => {
    const handlers = [
      player.connect("notify::playback-status", forceUpdate),
      player.connect("notify::title", forceUpdate),
      player.connect("notify::artist", forceUpdate),
    ];
    playerHandlers.set(player, handlers);
  });
};

setupPlayerWatchers();
mpris.connect("notify::players", setupPlayerWatchers);

// Get the active player (playing or first available)
export function getActivePlayer() {
  const playerList = mpris.players;
  return playerList.find((p: Mpris.Player) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING) || playerList[0];
}

// Reactive player info
export const currentPlayerInfo = updateId(() => {
  const player = getActivePlayer();
  if (!player) return "No media";
  const title = player.title || "Unknown";
  const artist = player.artist || "Unknown Artist";
  return `${title} - ${artist}`;
});

// Reactive play icon
export const currentPlayerPlayIcon = updateId(() => {
  const player = getActivePlayer();
  if (!player) return "⏸";
  return player.playbackStatus === Mpris.PlaybackStatus.PLAYING ? "⏸" : "▶";
});

// Media panel visibility
export const [mediaPanelVisible, setMediaPanelVisible] = createState(false);

export function showMediaPanel() {
  setMediaPanelVisible(true);
}

export function hideMediaPanel() {
  setMediaPanelVisible(false);
}

export function toggleMediaPanel() {
  const player = mpris.players.find((p: Mpris.Player) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING);
  if (player && hypr) {
    hypr.dispatch("focuswindow", `class:${player.entry}`);
  }
}
