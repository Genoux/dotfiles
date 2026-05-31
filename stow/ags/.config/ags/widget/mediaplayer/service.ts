import Playerctl from "gi://Playerctl";
import GLib from "gi://GLib";
import type Hyprland from "gi://AstalHyprland";
import { createState } from "ags";
import { execAsync } from "ags/process";
import { focusWindow, hypr } from "../../services/hyprland";

const manager = Playerctl.PlayerManager.new();

const [updateId, setUpdateId] = createState(0);
const updateSubscribers = new Set<() => void>();
export const [hasDisplayableMedia, setHasDisplayableMedia] = createState(false);
export const [currentPlayerInfo, setCurrentPlayerInfo] = createState("");
export const [currentPlayerPlayIcon, setCurrentPlayerPlayIcon] = createState("⏸");
let mediaStateReady = false;

const forceUpdate = () => {
  if (mediaStateReady) {
    updateMediaState();
  }
  setUpdateId((id) => id + 1);
  updateSubscribers.forEach((callback) => callback());
};

export function onMediaUpdate(callback: () => void): () => void {
  updateSubscribers.add(callback);
  return () => updateSubscribers.delete(callback);
}

/** Bar / tray only — window focus does not set this. */
const [lastExplicitId, setLastExplicitId] = createState<string | null>(null);

/**
 * Most-recent-first list of sources that have entered PLAYING (and explicit bar/tray picks).
 * Used to choose which session to show when several exist or after something stops.
 */
const RECENT_PLAYING_MAX = 12;
const recentPlayingOrder: string[] = [];
let managedPlayers: Playerctl.Player[] = [];

function playerNameStableId(name: Playerctl.PlayerName): string {
  return `${name.source}:${name.name}:${name.instance}`;
}

export function getPlayerStableId(player: Playerctl.Player): string {
  const name = (player.player_name || "").trim();
  const instance = (player.player_instance || "").trim();
  return `${player.source}:${name}:${instance}`;
}

function stableIdsMatch(stored: string | null, player: Playerctl.Player): boolean {
  if (!stored) return false;
  const id = getPlayerStableId(player);
  if (id === stored) return true;

  const storedParts = stored.toLowerCase().split(":");
  const idParts = id.toLowerCase().split(":");
  const storedName = storedParts[storedParts.length - 2];
  const storedInstance = storedParts[storedParts.length - 1];
  const idName = idParts[idParts.length - 2];
  const idInstance = idParts[idParts.length - 1];
  return storedName === idName && storedInstance === idInstance;
}

function pushRecentPlaying(player: Playerctl.Player) {
  const id = getPlayerStableId(player);
  if (!id) return;
  const rest = recentPlayingOrder.filter((sid) => !stableIdsMatch(sid, player));
  recentPlayingOrder.length = 0;
  recentPlayingOrder.push(id, ...rest);
  if (recentPlayingOrder.length > RECENT_PLAYING_MAX) {
    recentPlayingOrder.length = RECENT_PLAYING_MAX;
  }
}

function stackRank(player: Playerctl.Player): number {
  for (let i = 0; i < recentPlayingOrder.length; i++) {
    if (stableIdsMatch(recentPlayingOrder[i], player)) return i;
  }
  return RECENT_PLAYING_MAX + 1;
}

function pickByStackOrder(candidates: Playerctl.Player[]): Playerctl.Player | undefined {
  if (candidates.length === 0) return undefined;
  return [...candidates].sort((a, b) => stackRank(a) - stackRank(b))[0];
}

/** Tray / media bar controls only — not window focus, not automatic playback alone. */
export function markPlayerAsInteracted(player: Playerctl.Player) {
  const id = getPlayerStableId(player);
  if (!id) {
    return;
  }
  pushRecentPlaying(player);
  setLastExplicitId(id);
  forceUpdate();
}

export function markPlayerIdAsInteracted(id: string) {
  if (!id) return;
  const player = getPlayers().find((p) => stableIdsMatch(id, p));
  if (player) {
    markPlayerAsInteracted(player);
  } else {
    setLastExplicitId(id);
    forceUpdate();
  }
}

function getPlayers(): Playerctl.Player[] {
  return managedPlayers;
}

function pruneRecentPlayingOrder() {
  const next = recentPlayingOrder.filter((sid) => getPlayers().some((p) => stableIdsMatch(sid, p)));
  recentPlayingOrder.length = 0;
  recentPlayingOrder.push(...next);
}

function managePlayerName(name: Playerctl.PlayerName) {
  const id = playerNameStableId(name);
  if (getPlayers().some((player) => getPlayerStableId(player) === id)) {
    return;
  }

  try {
    const player = Playerctl.Player.new_from_name(name);
    managedPlayers.push(player);
    manager.manage_player(player);
  } catch (error) {
    console.error("[Media] Failed to manage player:", error);
  }
}

function pruneManagedPlayers(names: Playerctl.PlayerName[]) {
  const liveIds = new Set(names.map(playerNameStableId));
  managedPlayers = managedPlayers.filter((player) => liveIds.has(getPlayerStableId(player)));
}

const playerHandlers = new Map<Playerctl.Player, number[]>();

function seedPlayingPlayers() {
  getPlayers().forEach((player) => {
    if (getPlaybackStatus(player) === Playerctl.PlaybackStatus.PLAYING) {
      pushRecentPlaying(player);
    }
  });
}

function setupPlayerWatchers() {
  playerHandlers.forEach((handlers, player) => {
    handlers.forEach((handlerId) => player.disconnect(handlerId));
  });
  playerHandlers.clear();

  getPlayers().forEach((player) => {
    const onPlaybackChange = () => {
      const status = getPlaybackStatus(player);
      if (status === Playerctl.PlaybackStatus.PLAYING) {
        pushRecentPlaying(player);
      }
      forceUpdate();
    };

    const handlers = [
      player.connect("playback-status", onPlaybackChange),
      player.connect("metadata", forceUpdate),
      player.connect("exit", reconcilePlayers),
      player.connect("notify::playback-status", onPlaybackChange),
      player.connect("notify::metadata", forceUpdate),
    ];
    playerHandlers.set(player, handlers);
  });
}

function reconcilePlayers() {
  const names = Playerctl.list_players();
  pruneManagedPlayers(names);
  names.forEach(managePlayerName);
  pruneRecentPlayingOrder();

  const stored = lastExplicitId.peek();
  if (stored && !getPlayers().some((p) => stableIdsMatch(stored, p))) {
    setLastExplicitId(null);
  }

  setupPlayerWatchers();
  seedPlayingPlayers();
  forceUpdate();
}

function scheduleStartupReconcile() {
  let remaining = 8;
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    reconcilePlayers();
    remaining -= 1;
    return remaining > 0;
  });
}

/** Spotify and others update Hyprland title on play before metadata props refresh. */
const hyprTitleHandlers = new Map<Hyprland.Client, number>();

const setupHyprTitleWatchers = () => {
  if (!hypr) return;

  const live = new Set(hypr.get_clients());
  hyprTitleHandlers.forEach((handlerId, client) => {
    if (!live.has(client)) {
      try {
        client.disconnect(handlerId);
      } catch {
        /* client gone */
      }
      hyprTitleHandlers.delete(client);
    }
  });

  for (const client of live) {
    if (hyprTitleHandlers.has(client)) continue;
    const handlerId = client.connect("notify::title", forceUpdate);
    hyprTitleHandlers.set(client, handlerId);
  }
};

if (hypr) {
  setupHyprTitleWatchers();
  hypr.connect("notify::clients", setupHyprTitleWatchers);
}

function getPlaybackStatus(p: Playerctl.Player): Playerctl.PlaybackStatus | undefined {
  const ext = p as Playerctl.Player & { playback_status?: Playerctl.PlaybackStatus };
  const raw = ext.playback_status ?? p.playbackStatus;
  return raw as Playerctl.PlaybackStatus | undefined;
}

function getActivePlayers(): Playerctl.Player[] {
  const playing = Playerctl.PlaybackStatus.PLAYING;
  const paused = Playerctl.PlaybackStatus.PAUSED;
  const stopped = Playerctl.PlaybackStatus.STOPPED;

  const primary = getPlayers().filter((p) => {
    const st = getPlaybackStatus(p);
    return st === playing || st === paused;
  });
  if (primary.length > 0) {
    return primary;
  }

  const fallback = getPlayers().filter((p) => getPlaybackStatus(p) !== stopped);
  if (fallback.length > 0) {
    return fallback;
  }

  return getPlayers();
}

const UNKNOWN_MEDIA_LABELS = new Set([
  "unknown",
  "unknown title",
  "unknown artist",
  "unknown track",
  "no title",
  "no artist",
]);

function isUnknownMediaField(value: string | null | undefined): boolean {
  const trimmed = (value ?? "").trim();
  if (!trimmed) return true;
  return UNKNOWN_MEDIA_LABELS.has(trimmed.toLowerCase());
}

function safelyReadMetadata(player: Playerctl.Player, reader: () => string): string {
  try {
    return (reader.call(player) ?? "").trim();
  } catch {
    return "";
  }
}

function getPlayerTitle(player: Playerctl.Player): string {
  return safelyReadMetadata(player, player.get_title);
}

function getPlayerArtist(player: Playerctl.Player): string {
  return safelyReadMetadata(player, player.get_artist);
}

function entryClassHint(player: Playerctl.Player): string {
  return (player.player_name ?? "")
    .replace(/\.desktop$/i, "")
    .trim()
    .toLowerCase();
}

function isGenericWindowTitle(title: string, player: Playerctl.Player): boolean {
  const normalized = title.trim().toLowerCase();
  if (!normalized || isUnknownMediaField(normalized)) return true;
  const hint = entryClassHint(player);
  return hint.length > 0 && normalized === hint;
}

function getClientTitleForPlayer(player: Playerctl.Player): string | null {
  if (!hypr) return null;
  const hint = entryClassHint(player);
  if (!hint) return null;

  for (const client of hypr.get_clients()) {
    const cls = (client.get_class() ?? "").trim().toLowerCase();
    if (cls !== hint && !cls.includes(hint)) continue;
    const title = (client.get_title() ?? "").trim();
    if (isGenericWindowTitle(title, player)) return null;
    return title;
  }
  return null;
}

function getClientAddressForPlayer(player: Playerctl.Player): string | null {
  if (!hypr) return null;
  const hint = entryClassHint(player);
  if (!hint) return null;

  for (const client of hypr.get_clients()) {
    const cls = (client.get_class() ?? "").trim().toLowerCase();
    if (cls !== hint && !cls.includes(hint)) continue;
    return client.get_address();
  }

  return null;
}

function parseWindowMediaTitle(windowTitle: string): { artist: string; title: string } | null {
  const sep = " - ";
  const index = windowTitle.indexOf(sep);
  if (index <= 0) return null;
  const artist = windowTitle.slice(0, index).trim();
  const title = windowTitle.slice(index + sep.length).trim();
  if (isUnknownMediaField(artist) && isUnknownMediaField(title)) return null;
  return { artist, title };
}

function resolvedMediaFields(player: Playerctl.Player): { title: string; artist: string } {
  let title = getPlayerTitle(player);
  let artist = getPlayerArtist(player);

  if (!isUnknownMediaField(title) || !isUnknownMediaField(artist)) {
    return { title, artist };
  }

  const windowTitle = getClientTitleForPlayer(player);
  if (!windowTitle) return { title: "", artist: "" };

  const parsed = parseWindowMediaTitle(windowTitle);
  if (parsed) {
    if (isUnknownMediaField(title) && !isUnknownMediaField(parsed.title)) {
      title = parsed.title;
    }
    if (isUnknownMediaField(artist) && !isUnknownMediaField(parsed.artist)) {
      artist = parsed.artist;
    }
    return { title, artist };
  }

  if (isUnknownMediaField(title) && isUnknownMediaField(artist)) {
    return { title: windowTitle, artist: "" };
  }

  return { title, artist };
}

/** Bar label; needs at least one real title or artist. */
export function formatPlayerMediaLabel(player: Playerctl.Player): string | null {
  const { title, artist } = resolvedMediaFields(player);
  const hasTitle = !isUnknownMediaField(title);
  const hasArtist = !isUnknownMediaField(artist);
  if (!hasTitle && !hasArtist) return null;
  if (hasTitle && hasArtist) return `${title} - ${artist}`;
  if (hasArtist) return artist;
  return title;
}

export function hasDisplayableMetadata(player: Playerctl.Player): boolean {
  return formatPlayerMediaLabel(player) !== null;
}

function getPlayerSourceLabel(player: Playerctl.Player): string {
  const name = (player.player_name ?? "").replace(/[._-]+/g, " ").trim();
  if (!isUnknownMediaField(name)) return name;

  return "Media";
}

function formatPlayerDisplayLabel(player: Playerctl.Player): string {
  return formatPlayerMediaLabel(player) ?? getPlayerSourceLabel(player);
}

function pickActivePlayer(explicitId: string | null): Playerctl.Player | undefined {
  const active = getActivePlayers();
  if (active.length === 0) return undefined;

  const playing = active.filter((p) => getPlaybackStatus(p) === Playerctl.PlaybackStatus.PLAYING);

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

export function getActivePlayer(): Playerctl.Player | undefined {
  return pickActivePlayer(lastExplicitId.peek());
}

export function isActivePlayerPlaying(): boolean {
  const player = getActivePlayer();
  return !!player && getPlaybackStatus(player) === Playerctl.PlaybackStatus.PLAYING;
}

function updateMediaState() {
  const player = pickActivePlayer(lastExplicitId());
  if (!player) {
    setHasDisplayableMedia(false);
    setCurrentPlayerInfo("");
    setCurrentPlayerPlayIcon("⏸");
    return;
  }

  const status = getPlaybackStatus(player);
  setHasDisplayableMedia(status !== Playerctl.PlaybackStatus.STOPPED);
  setCurrentPlayerInfo(formatPlayerDisplayLabel(player));
  setCurrentPlayerPlayIcon(status === Playerctl.PlaybackStatus.PLAYING ? "⏸" : "▶");
}

manager.connect("name-appeared", (_manager, name) => {
  managePlayerName(name);
  reconcilePlayers();
});
manager.connect("name-vanished", reconcilePlayers);
manager.connect("player-appeared", reconcilePlayers);
manager.connect("player-vanished", reconcilePlayers);

mediaStateReady = true;
reconcilePlayers();
scheduleStartupReconcile();

export const [mediaPanelVisible, setMediaPanelVisible] = createState(false);

export function showMediaPanel() {
  setMediaPanelVisible(true);
}

export function hideMediaPanel() {
  setMediaPanelVisible(false);
}

export async function focusActivePlayerWindow(): Promise<void> {
  const player = getActivePlayer();
  if (!player) return;

  markPlayerAsInteracted(player);

  let clients: { address?: string; class?: string; initialClass?: string; title?: string }[];
  try {
    const json = await execAsync(["hyprctl", "clients", "-j"]);
    clients = JSON.parse(json);
  } catch {
    return;
  }

  const playerName = (player.player_name ?? "").toLowerCase();
  const instance = (player.player_instance ?? "").toLowerCase();
  const tokens = [...new Set([playerName, instance, ...playerName.split(/[._-]+/)])].filter(
    (t) => t && t.length > 2
  );

  const classMatch = clients.find((c) => {
    const cls = (c.class || "").toLowerCase();
    const initialClass = (c.initialClass || "").toLowerCase();
    return tokens.some(
      (tok) => cls.includes(tok) || initialClass.includes(tok) || tok.includes(cls)
    );
  });

  if (classMatch?.address) {
    await focusWindow(`address:${classMatch.address}`);
    return;
  }

  // Fallback for browsers where player_name (e.g. "firefox") doesn't match window class (e.g. "zen")
  const trackTitle = getPlayerTitle(player);
  if (!isUnknownMediaField(trackTitle)) {
    const normalizedTitle = trackTitle.toLowerCase();
    const titleMatch = clients.find((c) => (c.title || "").toLowerCase().includes(normalizedTitle));
    if (titleMatch?.address) {
      await focusWindow(`address:${titleMatch.address}`);
    }
  }
}

export function toggleMediaPanel() {
  void focusActivePlayerWindow();
}
