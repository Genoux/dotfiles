import Wp from "gi://AstalWp"

// Shared utility functions for audio controls

export function getVolumeIcon(volume: number, muted: boolean): string {
    if (muted) return "audio-volume-muted-symbolic"
    
    if (volume > 0.6) return "audio-volume-high-symbolic"
    if (volume > 0.3) return "audio-volume-medium-symbolic"
    if (volume > 0) return "audio-volume-low-symbolic"
    // Show low volume icon even at 0 if not muted - only mute button should show muted icon
    return "audio-volume-low-symbolic"
}

// Clamp volume to prevent going over 100%
export function clampVolume(volume: number): number {
    return Math.min(Math.max(volume, 0), 1.0)
}

// Global OSD suppression system
let osdSuppressed = false
let suppressTimeout: any = null

export function suppressOSD(duration: number = 500) {
    osdSuppressed = true
    
    if (suppressTimeout) {
        clearTimeout(suppressTimeout)
    }
    
    suppressTimeout = setTimeout(() => {
        osdSuppressed = false
        suppressTimeout = null
    }, duration)
}

export function isOSDSuppressed(): boolean {
    return osdSuppressed
}

// System volume limiter - actively prevents system volume from exceeding 100%
export function setupVolumeLimiter(speaker: any) {
    let isLimiting = false
    let limitTimeout: any = null
    
    const limitVolume = () => {
        if (isLimiting) return // Prevent recursion
        
        if (speaker.volume > 1.0) {
            isLimiting = true
            speaker.volume = 1.0
            
            // Clear any existing timeout
            if (limitTimeout) {
                clearTimeout(limitTimeout)
            }
            
            // Reset limiting flag after a shorter delay for smoother operation
            limitTimeout = setTimeout(() => { 
                isLimiting = false 
                limitTimeout = null
            }, 50) // Reduced from 100ms to 50ms for more responsive limiting
        }
    }
    
    // Monitor volume changes and limit them
    speaker.connect("notify::volume", limitVolume)
    
    // Also check immediately in case it's already over 100%
    limitVolume()
}

// Global audio setup - call this once to initialize volume limiting system-wide
let audioInitialized = false
export function initializeAudioSystem() {
    if (audioInitialized) return
    
    try {
        const audio = Wp.get_default()
        const speaker = audio?.get_default_speaker()
        
        if (speaker) {
            setupVolumeLimiter(speaker)
            audioInitialized = true
        } else {
            console.warn("No speaker found for audio system initialization")
        }
    } catch (error) {
        console.error("Failed to initialize audio system:", error)
    }
} 