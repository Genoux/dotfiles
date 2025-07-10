import { Widget, Astal, Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"
import Mpris from "gi://AstalMpris"

// Global state management
export const playerInteractions = new Map<string, number>()
export const lastActivePlayer = Variable<Mpris.Player | null>(null)
export const globalUpdateTrigger = Variable(0)

// Track interaction with a player
export function trackPlayerInteraction(player: Mpris.Player) {
    const busName = player.busName
    const now = Date.now()
    
    playerInteractions.set(busName, now)
    lastActivePlayer.set(player)
    
    // Trigger immediate UI update
    globalUpdateTrigger.set(globalUpdateTrigger.get() + 1)
}

// Set up monitoring for when players start playing (implicit interaction)
export function setupPlaybackMonitoring(players: Mpris.Player[]) {
    players.forEach(player => {
        let previousStatus = player.playbackStatus
        
        player.connect("notify::playback-status", () => {
            const currentStatus = player.playbackStatus
            
            // If player started playing (was not playing before), treat as interaction
            if (currentStatus === Mpris.PlaybackStatus.PLAYING && 
                previousStatus !== Mpris.PlaybackStatus.PLAYING) {
                trackPlayerInteraction(player)
            }
            
            previousStatus = currentStatus
        })
    })
}

// Get the most recently interacted player (simple timestamp-based)
export function getMostRecentPlayer(players: Mpris.Player[]): Mpris.Player | null {
    if (players.length === 0) return null
    if (players.length === 1) return players[0]
    
    // Find player with most recent interaction
    let mostRecentPlayer = players[0]
    let mostRecentTime = playerInteractions.get(mostRecentPlayer.busName) || 0
    
    for (const player of players) {
        const interactionTime = playerInteractions.get(player.busName) || 0
        if (interactionTime > mostRecentTime) {
            mostRecentTime = interactionTime
            mostRecentPlayer = player
        }
    }
    
    return mostRecentPlayer
}


// Utility Functions
export function lengthStr(length: number) {
    const hours = Math.floor(length / 3600);
    const min = Math.floor((length % 3600) / 60);
    const sec = Math.floor(length % 60);
    const sec0 = sec < 10 ? "0" : "";
    const min0 = hours > 0 && min < 10 ? "0" : "";
  
    if (hours > 0) {
      return `${hours}:${min0}${min}:${sec0}${sec}`;
    } else {
      return `${min}:${sec0}${sec}`;
    }
  }

// Create a variable that tracks if there are any players available
const mpris = Mpris.get_default()
export const hasMediaPlayers = bind(mpris, "players").as(players => players.length > 0)