import Mpris from "gi://AstalMpris";
import { createState } from "ags";
import { hypr } from "../../services/hyprland";

const mpris = Mpris.get_default();

const [updateId, setUpdateId] = createState(0);
const forceUpdate = () => setUpdateId((id) => id + 1);

/** Bar / tray only — window focus does not set this. */
const [lastExplicitId, setLastExplicitId] = createState<string | null>(null);

/**
 * Most-recent-first list of sources that have entered PLAYING (and explicit bar/tray picks).
 * Used to choose which session to show when several exist or after something stops.
 */
const RECENT_PLAYING_MAX = 12;
const recentPlayingOrder: string[] = [];

function mprisBusSuffix(busName: string): string {
  return busName.replace(/^org\.mpris\.MediaPlayer2\./i, "").toLowerCase();
}

/** Stable per-session id; prefer D-Bus bus name over identity (identity can be empty or duplicate). */
export function getPlayerStableId(player: Mpris.Player): string {
  const p = player as Mpris.Player & { get_bus_name?: () => string };
  const bus = (player.bus_name || p.get_bus_name?.() || "").trim();
  if (bus) return bus;
  const ident = (player.identity || "").trim();
  if (ident) return ident;
  return (player.entry || "").replace(/\.desktop$/i, "").trim();
}

function stableIdsMatch(stored: string | null, player: Mpris.Player): boolean {
  if (!stored) return false;
  const id = getPlayerStableId(player);
  if (id === stored) return true;
  const a = stored.toLowerCase();
  const b = id.toLowerCase();
  if (a === b) return true;
  const sa = mprisBusSuffix(a);
  const sb = mprisBusSuffix(b);
  return sa.length > 0 && sb.length > 0 && (sa === sb || a.endsWith(sb) || b.endsWith(sa));
}

function pushRecentPlaying(player: Mpris.Player) {
  const id = getPlayerStableId(player);
  if (!id) return;
  const rest = recentPlayingOrder.filter((sid) => !stableIdsMatch(sid, player));
  recentPlayingOrder.length = 0;
  recentPlayingOrder.push(id, ...rest);
  if (recentPlayingOrder.length > RECENT_PLAYING_MAX) {
    recentPlayingOrder.length = RECENT_PLAYING_MAX;
  }
}

function stackRank(player: Mpris.Player): number {
  const id = getPlayerStableId(player);
  for (let i = 0; i < recentPlayingOrder.length; i++) {
    if (stableIdsMatch(recentPlayingOrder[i], player)) return i;
  }
  return RECENT_PLAYING_MAX + 1;
}

function pickByStackOrder(candidates: Mpris.Player[]): Mpris.Player | undefined {
  if (candidates.length === 0) return undefined;
  return [...candidates].sort((a, b) => stackRank(a) - stackRank(b))[0];
}

/** Tray / media bar controls only — not window focus, not automatic playback alone. */
export function markPlayerAsInteracted(player: Mpris.Player) {
  const id = getPlayerStableId(player);
  if (!id) {
    return;
  }
  pushRecentPlaying(player);
  setLastExplicitId(id);
  forceUpdate();
}

function pruneRecentPlayingOrder() {
  const next = recentPlayingOrder.filter((sid) =>
    mpris.players.some((p) => stableIdsMatch(sid, p)),
  );
  recentPlayingOrder.length = 0;
  recentPlayingOrder.push(...next);
}

mpris.connect("notify::players", () => {
  pruneRecentPlayingOrder();
  const stored = lastExplicitId.peek();
  if (stored && !mpris.players.some((p) => stableIdsMatch(stored, p))) {
    setLastExplicitId(null);
  }
  forceUpdate();
});

const playerHandlers = new Map<Mpris.Player, number[]>();

const setupPlayerWatchers = () => {
  playerHandlers.forEach((handlers, player) => {
    handlers.forEach((handlerId) => player.disconnect(handlerId));
  });
  playerHandlers.clear();

  mpris.players.forEach((player) => {
    const onPlaybackChange = () => {
      const status = getPlaybackStatus(player);
      if (status === Mpris.PlaybackStatus.PLAYING) {
        pushRecentPlaying(player);
      }
      const notPlaying =
        status === Mpris.PlaybackStatus.PAUSED || status === Mpris.PlaybackStatus.STOPPED;
      if (notPlaying) {
        const anotherIsPlaying = mpris.players.some(
          (p) => p !== player && getPlaybackStatus(p) === Mpris.PlaybackStatus.PLAYING,
        );
        if (anotherIsPlaying) {
          forceUpdate();
          return;
        }
      }
      forceUpdate();
    };
    const handlers = [
      player.connect("notify::playback-status", onPlaybackChange),
      player.connect("notify::metadata", forceUpdate),
      player.connect("notify::title", forceUpdate),
      player.connect("notify::artist", forceUpdate),
    ];
    playerHandlers.set(player, handlers);
  });
};

setupPlayerWatchers();
mpris.connect("notify::players", setupPlayerWatchers);

function getPlaybackStatus(p: Mpris.Player): Mpris.PlaybackStatus | undefined {
  const ext = p as Mpris.Player & { playback_status?: Mpris.PlaybackStatus };
  const raw = ext.playback_status ?? p.playbackStatus;
  return raw as Mpris.PlaybackStatus | undefined;
}

function getActivePlayers(): Mpris.Player[] {
  const playing = Mpris.PlaybackStatus.PLAYING;
  const paused = Mpris.PlaybackStatus.PAUSED;
  const stopped = Mpris.PlaybackStatus.STOPPED;

  const primary = mpris.players.filter((p) => {
    const st = getPlaybackStatus(p);
    return st === playing || st === paused;
  });
  if (primary.length > 0) {
    return primary;
  }

  const fallback = mpris.players.filter((p) => getPlaybackStatus(p) !== stopped);
  if (fallback.length > 0) {
    return fallback;
  }

  return mpris.players;
}

function pickActivePlayer(explicitId: string | null): Mpris.Player | undefined {
  const active = getActivePlayers();
  if (active.length === 0) return undefined;

  const playing = active.filter((p) => getPlaybackStatus(p) === Mpris.PlaybackStatus.PLAYING);

  if (playing.length > 0) {
    if (explicitId) {
      const hit = playing.find((p) => stableIdsMatch(explicitId, p));
      if (hit) return hit;
    }
    return pickByStackOrder(playing);
  }

  if (explicitId) {
    const hit = active.find((p) => stableIdsMatch(explicitId, p));
    if (hit) return hit;
  }

  return pickByStackOrder(active);
}

export function getActivePlayer(): Mpris.Player | undefined {
  return pickActivePlayer(lastExplicitId.peek());
}

export const currentPlayerInfo = updateId(() => {
  const explicit = lastExplicitId();
  const player = pickActivePlayer(explicit);
  if (!player) return "No media";
  const title = player.title || "Unknown";
  const artist = player.artist || "Unknown Artist";
  return `${title} - ${artist}`;
});

export const currentPlayerPlayIcon = updateId(() => {
  const explicit = lastExplicitId();
  const player = pickActivePlayer(explicit);
  if (!player) return "⏸";
  return getPlaybackStatus(player) === Mpris.PlaybackStatus.PLAYING ? "⏸" : "▶";
});

export const [mediaPanelVisible, setMediaPanelVisible] = createState(false);

export function showMediaPanel() {
  setMediaPanelVisible(true);
}

export function hideMediaPanel() {
  setMediaPanelVisible(false);
}

export function toggleMediaPanel() {
  const player = getActivePlayer();
  if (!player) {
    return;
  }
  if (player.can_raise) {
    player.raise();
    return;
  }
  if (hypr && player.entry) {
    const cls = player.entry.replace(/\.desktop$/i, "");
    hypr.dispatch("focuswindow", `class:${cls}`);
  }
}
