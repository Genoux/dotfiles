import { Astal, Gtk } from "astal/gtk3"
import Wp from "gi://AstalWp"
import { bind, Variable } from "astal"
import AudioButton from "./AudioButton"

// Utility Functions
function volumeIcon(volume: number, muted: boolean) {
    if (muted) return "audio-volume-muted-symbolic"
    if (volume === 0) return "audio-volume-low-symbolic"
    if (volume < 0.33) return "audio-volume-low-symbolic"
    if (volume < 0.66) return "audio-volume-medium-symbolic"
    return "audio-volume-high-symbolic"
}

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

    const sliderValue = Variable(speaker.volume)
    
    // Derived variable for icon that updates with both volume and mute
    const iconName = Variable.derive([
        bind(speaker, "volume"),
        bind(speaker, "mute")
    ], (volume, mute) => volumeIcon(volume, mute))
    
    // Simple: just update when not dragging
    let isDragging = false
    let ignoreNotifications = false
    let lastVolumeUpdate = 0
    
    speaker.connect("notify::volume", () => {
        if (!isDragging && !ignoreNotifications) {
            sliderValue.set(speaker.volume)
        }
    })
    
    return <box className="AudioPanel" spacing={8}>
        <AudioButton />
        <slider
            hexpand
            value={bind(sliderValue)}
            onButtonPressEvent={() => {
                isDragging = true
                return false
            }}
            onButtonReleaseEvent={() => {
                // Always set the final value to ensure accuracy
                speaker.volume = sliderValue.get()
                if (sliderValue.get() > 0) {
                    speaker.mute = false
                }
                
                isDragging = false
                // Ignore notifications briefly to prevent feedback
                ignoreNotifications = true
                setTimeout(() => { ignoreNotifications = false }, 150)
                return false
            }}
            onDragged={({ value }) => {
                // Update UI immediately
                sliderValue.set(value)
                
                // Throttle volume updates to reduce queued notifications
                const now = Date.now()
                if (now - lastVolumeUpdate > 50) { // Max 20 updates/second
                    speaker.volume = value
                    if (value > 0) {
                        speaker.mute = false
                    }
                    lastVolumeUpdate = now
                }
            }}
        />
        <label 
            className="volume-label"
            label={bind(sliderValue).as(v => `${Math.round(v * 100)}%`)}
        />
    </box>
} 