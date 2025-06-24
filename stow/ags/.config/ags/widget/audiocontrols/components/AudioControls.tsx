import { Astal, Gtk } from "astal/gtk3"
import Wp from "gi://AstalWp"
import { bind, Variable } from "astal"
import AudioButton from "./AudioButton"
import { getVolumeIcon, clampVolume, initializeAudioSystem, suppressOSD } from "../utils"

export default function AudioControlsComponent(): Gtk.Widget {
    const audio = Wp.get_default()
    
    if (!audio) {
        return <box className="AudioPanel">
            <label label="Audio system not available" />
        </box>
    }
    
    const speaker = audio.get_default_speaker()
    
    if (!speaker) {
        return <box className="AudioPanel">
            <label label="No audio device" />
        </box>
    }

    // Initialize global audio system (volume limiter, etc.)
    initializeAudioSystem()

    const sliderValue = Variable(clampVolume(speaker.volume))
    
    // Derived variable for icon that updates with both volume and mute
    const iconName = Variable.derive([
        bind(speaker, "volume"),
        bind(speaker, "mute")
    ], (volume, mute) => getVolumeIcon(clampVolume(volume), mute))
    
    // Optimized for responsive volume changes
    let isDragging = false
    let ignoreNotifications = false
    let lastVolumeUpdate = 0
    let ignoreTimeout: any = null
    
    speaker.connect("notify::volume", () => {
        if (!isDragging && !ignoreNotifications) {
            sliderValue.set(clampVolume(speaker.volume))
        }
    })
    
    return <box className="AudioPanel" spacing={8}>
        <AudioButton />
        <slider
            hexpand
            value={bind(sliderValue)}
            max={1.0}
            min={0.0}
            step={0.01}
            onButtonPressEvent={() => {
                isDragging = true
                // Suppress OSD while dragging
                suppressOSD(1000) // Suppress for 1 second initially
                return false
            }}
            onButtonReleaseEvent={() => {
                // Always set the final value to ensure accuracy, but clamp it
                const clampedValue = clampVolume(sliderValue.get())
                speaker.volume = clampedValue
                if (clampedValue > 0) {
                    speaker.mute = false
                }
                
                isDragging = false
                // Ignore notifications briefly to prevent feedback with improved timeout handling
                ignoreNotifications = true
                
                if (ignoreTimeout) {
                    clearTimeout(ignoreTimeout)
                }
                
                ignoreTimeout = setTimeout(() => { 
                    ignoreNotifications = false 
                    ignoreTimeout = null
                }, 100) // Reduced from 150ms for more responsive updates
                
                // Keep OSD suppressed for a bit longer after release
                suppressOSD(300)
                
                return false
            }}
            onDragged={({ value }) => {
                // Clamp the value before using it
                const clampedValue = clampVolume(value)
                sliderValue.set(clampedValue)
                
                // Continue suppressing OSD while dragging
                suppressOSD(500)
                
                // Reduced throttling for smoother continuous volume changes
                const now = Date.now()
                if (now - lastVolumeUpdate > 25) { // Reduced from 50ms to 25ms for smoother operation
                    speaker.volume = clampedValue
                    if (clampedValue > 0) {
                        speaker.mute = false
                    }
                    lastVolumeUpdate = now
                }
            }}
        />
        <label 
            className="volume-label"
            label={bind(sliderValue).as(v => `${Math.round(clampVolume(v) * 100)}%`)}
        />
    </box>
} 