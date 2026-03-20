import Mpris from "gi://AstalMpris";
import { createState } from "ags";
import { hypr } from "../../services/hyprland";

const mpris = Mpris.get_default();

// Use counter to force reactive updates when player state changes
const [updateId, setUpdateId] = createState(0);
const forceUpdate = () => setUpdateId((id) => id + 1);

let lastInteractedIdentity: string | null = null;

function getPlayerIdentity(player: Mpris.Player): string {
  return (player as any).identity ?? (player as any).bus_name ?? "";
}

export function markPlayerAsInteracted(player: Mpris.Player) {
  const identity = getPlayerIdentity(player);
  if (identity) {
    lastInteractedIdentity = identity;
    forceUpdate();
  }
}

// Listen to player changes - clear lastInteracted if that player is gone
mpris.connect("notify::players", () => {
  if (lastInteractedIdentity && !mpris.players.some((p) => getPlayerIdentity(p) === lastInteractedIdentity)) {
    lastInteractedIdentity = null;
  }
  forceUpdate();
});

// Track player handlers to prevent duplicate connections
const playerHandlers = new Map<Mpris.Player, number[]>();

const setupPlayerWatchers = () => {
  // Disconnect old handlers
  playerHandlers.forEach((handlers, player) => {
    handlers.forEach((handlerId) => player.disconnect(handlerId));
  });
  playerHandlers.clear();

  // Connect new handlers - mark as interacted when a player starts playing (user switched source)
  mpris.players.forEach((player) => {
    const onStatusChange = () => {
      if (player.playbackStatus === Mpris.PlaybackStatus.PLAYING) {
        markPlayerAsInteracted(player);
      }
      forceUpdate();
    };
    const handlers = [
      player.connect("notify::playback-status", onStatusChange),
      player.connect("notify::title", forceUpdate),
      player.connect("notify::artist", forceUpdate),
    ];
    playerHandlers.set(player, handlers);
  });
};

setupPlayerWatchers();
mpris.connect("notify::players", setupPlayerWatchers);

function getActivePlayers(): Mpris.Player[] {
  return mpris.players.filter((p) => {
    const isActive = p.playbackStatus === Mpris.PlaybackStatus.PLAYING ||
                     p.playbackStatus === Mpris.PlaybackStatus.PAUSED;
    return isActive && p.canControl;
  });
}

// Get the active player - prefer last-interacted, else first playing then first paused
export function getActivePlayer(): Mpris.Player | undefined {
  const active = getActivePlayers();
  if (active.length === 0) return undefined;

  if (lastInteractedIdentity) {
    const lastInteracted = active.find((p) => getPlayerIdentity(p) === lastInteractedIdentity);
    if (lastInteracted) return lastInteracted;
  }

  return active.find((p) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING) ?? active[0];
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
  const player = getActivePlayer();
  if (player && hypr && (player as any).entry) {
    hypr.dispatch("focuswindow", `class:${(player as any).entry}`);
  }
}
