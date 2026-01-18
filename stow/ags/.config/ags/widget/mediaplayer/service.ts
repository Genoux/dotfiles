import Mpris from "gi://AstalMpris";
import { createState } from "ags";
import { hypr } from "../../services/hyprland";

const mpris = Mpris.get_default();

// Use counter to force reactive updates when player state changes
const [updateId, setUpdateId] = createState(0);
const forceUpdate = () => setUpdateId((id) => id + 1);

// Track last known player to show last content even when stopped
let lastKnownPlayer: Mpris.Player | null = null;
// Track the most recently playing player (takes priority)
let currentPlayingPlayer: Mpris.Player | null = null;
// Track the player the user last interacted with (for icon/display)
let lastInteractedPlayer: Mpris.Player | null = null;

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
  mpris.players.forEach((player) => {
    const onPlaybackStatusChange = () => {
      // When a player starts playing, immediately set it as current
      if (player.playbackStatus === Mpris.PlaybackStatus.PLAYING) {
        currentPlayingPlayer = player;
        lastKnownPlayer = player;
        // If this player starts playing, it becomes the last interacted player
        lastInteractedPlayer = player;
      } else {
        // If this player stops playing and it was our current, clear it
        if (currentPlayingPlayer === player) {
          currentPlayingPlayer = null;
        }
      }
      forceUpdate();
    };

    const handlers = [
      player.connect("notify::playback-status", onPlaybackStatusChange),
      player.connect("notify::metadata", forceUpdate), // Listen to metadata changes (catches all metadata updates)
      player.connect("notify::title", forceUpdate),
      player.connect("notify::artist", forceUpdate),
    ];
    playerHandlers.set(player, handlers);
    
    // If this player is already playing, set it as current
    if (player.playbackStatus === Mpris.PlaybackStatus.PLAYING) {
      currentPlayingPlayer = player;
      lastKnownPlayer = player;
    }
  });
};

setupPlayerWatchers();
mpris.connect("notify::players", () => {
  // When players list changes, check for playing players
  const playingPlayers = mpris.players.filter((p) => 
    p.playbackStatus === Mpris.PlaybackStatus.PLAYING && p.canControl
  );
  
  // If there are playing players, set the first one as current
  if (playingPlayers.length > 0) {
    // If currentPlayingPlayer is not in the playing list, switch to a new one
    if (!currentPlayingPlayer || !playingPlayers.includes(currentPlayingPlayer)) {
      currentPlayingPlayer = playingPlayers[0];
      lastKnownPlayer = currentPlayingPlayer;
    }
  } else {
    // No players are playing, clear current
    currentPlayingPlayer = null;
  }
  
  setupPlayerWatchers();
});

// Set the player the user interacted with (called from button clicks)
export function setInteractedPlayer(player: Mpris.Player | null) {
  if (player) {
    lastInteractedPlayer = player;
    lastKnownPlayer = player;
    if (player.playbackStatus === Mpris.PlaybackStatus.PLAYING) {
      currentPlayingPlayer = player;
    }
    forceUpdate();
  }
}

// Get the active player (prioritize last interacted > playing > paused > stopped with last known content)
export function getActivePlayer() {
  const playerList = mpris.players;
  
  // First, check if we have a last interacted player that still exists and has metadata
  if (lastInteractedPlayer) {
    const stillExists = playerList.some((p) => p === lastInteractedPlayer);
    if (stillExists) {
      const hasMetadata = lastInteractedPlayer.title || lastInteractedPlayer.artist;
      const status = lastInteractedPlayer.playbackStatus;
      // Use last interacted player if it has metadata and is not stopped
      if (hasMetadata && lastInteractedPlayer.canControl && 
          status !== Mpris.PlaybackStatus.STOPPED) {
        return lastInteractedPlayer;
      }
    } else {
      // Player was removed, clear it
      lastInteractedPlayer = null;
    }
  }
  
  // Then, check if we have a tracked current playing player that's still playing
  if (currentPlayingPlayer) {
    const stillExists = playerList.some((p) => p === currentPlayingPlayer);
    if (stillExists && 
        currentPlayingPlayer.playbackStatus === Mpris.PlaybackStatus.PLAYING &&
        currentPlayingPlayer.canControl) {
      return currentPlayingPlayer;
    } else {
      // Current player is no longer valid, clear it
      currentPlayingPlayer = null;
    }
  }
  
  // Find all playing players
  const playingPlayers = playerList.filter((p) => {
    return p.playbackStatus === Mpris.PlaybackStatus.PLAYING && p.canControl;
  });
  
  if (playingPlayers.length > 0) {
    // Use the first playing player and track it
    const activePlayer = playingPlayers[0];
    currentPlayingPlayer = activePlayer;
    lastKnownPlayer = activePlayer;
    lastInteractedPlayer = activePlayer;
    return activePlayer;
  }
  
  // Then, try to find a paused player
  const pausedPlayers = playerList.filter((p) => {
    return p.playbackStatus === Mpris.PlaybackStatus.PAUSED && p.canControl;
  });
  
  if (pausedPlayers.length > 0) {
    const pausedPlayer = pausedPlayers[0];
    lastKnownPlayer = pausedPlayer;
    return pausedPlayer;
  }
  
  // Finally, return last known player if it still exists and has metadata
  // But only if it's not stopped (we don't want to show stopped players)
  if (lastKnownPlayer) {
    // Check if player is still in the list
    const stillExists = playerList.some((p) => p === lastKnownPlayer);
    if (stillExists) {
      const status = lastKnownPlayer.playbackStatus;
      const hasMetadata = lastKnownPlayer.title || lastKnownPlayer.artist;
      // Only use lastKnownPlayer if it's paused (not stopped) and has metadata
      if (hasMetadata && lastKnownPlayer.canControl && 
          status !== Mpris.PlaybackStatus.STOPPED) {
        return lastKnownPlayer;
      }
    } else {
      // Player was removed, clear it
      lastKnownPlayer = null;
    }
  }
  
  // Fallback to first available player with metadata (but not stopped)
  const fallbackPlayer = playerList.find((p) => {
    const hasMetadata = p.title || p.artist;
    const notStopped = p.playbackStatus !== Mpris.PlaybackStatus.STOPPED;
    return p.canControl && hasMetadata && notStopped;
  });
  
  if (fallbackPlayer) {
    lastKnownPlayer = fallbackPlayer;
    return fallbackPlayer;
  }
  
  return null;
}

// Reactive player info
export const currentPlayerInfo = updateId(() => {
  const player = getActivePlayer();
  if (!player) return "No media";
  
  // Get title and artist, but don't show "Unknown" if we have at least one
  const title = player.title?.trim() || "";
  const artist = player.artist?.trim() || "";
  
  // If we have both, show both
  if (title && artist) {
    return `${title} - ${artist}`;
  }
  // If we only have title, show title
  if (title) {
    return title;
  }
  // If we only have artist, show artist
  if (artist) {
    return artist;
  }
  // Only show "Unknown" if we truly have nothing
  return "Unknown";
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
  const player = mpris.players.find((p) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING);
  if (player && hypr) {
    hypr.dispatch("focuswindow", `class:${player.entry}`);
  }
}
