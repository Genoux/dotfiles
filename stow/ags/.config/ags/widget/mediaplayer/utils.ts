import Mpris from "gi://AstalMpris"
import { getMostRecentPlayer } from "./Service"

// Get the currently active media player
export function getCurrentMediaPlayer(): Mpris.Player | null {
  try {
    const mpris = Mpris.get_default()
    const players = mpris.players
    
    if (players.length === 0) return null
    
    // Use the same logic as MediaPlayer component
    return getMostRecentPlayer(players)
  } catch (error) {
    console.error("Failed to get current media player:", error)
    return null
  }
}

// Get the app class/entry of the current media player (for focusing windows)
export function getCurrentMediaSource(): string | null {
  try {
    const activePlayer = getCurrentMediaPlayer()
    return activePlayer?.entry || null
  } catch (error) {
    console.error("Failed to get current media source:", error)
    return null
  }
}

// Check if there's currently playing media
export function isMediaPlaying(): boolean {
  try {
    const activePlayer = getCurrentMediaPlayer()
    return activePlayer?.playbackStatus === Mpris.PlaybackStatus.PLAYING || false
  } catch (error) {
    return false
  }
}

// Get current track info (useful for tooltips, etc.)
export function getCurrentTrackInfo(): { title: string; artist: string; player: string } | null {
  try {
    const activePlayer = getCurrentMediaPlayer()
    
    if (!activePlayer) return null
    
    return {
      title: activePlayer.title || "Unknown Track",
      artist: activePlayer.artist || "Unknown Artist", 
      player: activePlayer.identity || activePlayer.entry || "Unknown Player"
    }
  } catch (error) {
    return null
  }
} 