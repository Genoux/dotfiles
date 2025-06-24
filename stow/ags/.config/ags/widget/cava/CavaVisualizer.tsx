import { Gtk } from "astal/gtk3"
import { Variable, bind } from "astal"
import { subprocess } from "astal/process"

const cavaData = Variable<number[]>([])
export const isPlaying = Variable(false)

class CavaManager {
  private cavaProcess: any = null
  private audioCheckInterval: any = null

  constructor() {
    console.log("CAVA Manager initialized - monitoring system audio")
    this.startAudioDetection()
  }

  private setupCava() {
    if (this.cavaProcess) {
      this.cavaProcess.kill()
    }

    try {
      this.cavaProcess = subprocess(
        ["cava", "-p", "/home/john/dotfiles/stow/cava/.config/cava/config"],
        (output) => {
          if (output.trim()) {
            const values = output.trim().split(';').map(Number).filter(n => !isNaN(n))
            if (values.length >= 8) {
              const normalizedValues = values.slice(0, 8).map((val: number) =>
                Math.floor((val / 1000) * 7)
              )
              cavaData.set(normalizedValues)
              
              // If we're getting audio data, we're playing
              const hasAudio = normalizedValues.some(val => val > 0)
              if (hasAudio && !isPlaying.get()) {
                isPlaying.set(true)
                console.log("CAVA: Audio detected, showing visualizer")
              }
            }
          }
        },
        (error) => {
          console.error("CAVA process error:", error)
        }
      )
      console.log("CAVA subprocess started successfully")
    } catch (error) {
      console.error("Failed to start CAVA subprocess:", error)
    }
  }

  private startAudioDetection() {
    // Start CAVA immediately to monitor system audio
    this.setupCava()
    
    // Check for audio activity every few seconds
    this.audioCheckInterval = setInterval(() => {
      const currentData = cavaData.get()
      const hasAudio = currentData.some(val => val > 0)
      
      if (!hasAudio && isPlaying.get()) {
        // No audio detected for a while, hide the visualizer
        console.log("CAVA: No audio detected, hiding visualizer")
        isPlaying.set(false)
        cavaData.set([])
      }
    }, 50) // Check every 3 seconds
  }
}

function VisualizerBars() {
  return (
    <box className="cava-bars" spacing={2}>
      {bind(cavaData).as(bars =>
        bars.map((height) => (
          <box
            className={`cava-bar cava-bar-${height}`}
            widthRequest={2}
            heightRequest={height === 0 ? 0 : Math.max(3, height * 2)}
            valign={Gtk.Align.END}
          />
        ))
      )}
    </box>
  )
}

// Initialize the CAVA manager
const cavaManager = new CavaManager()

export default function CavaVisualizer() {
  console.log("🎵 CavaVisualizer: Component rendered")
  return (
    <box className="cava-island" spacing={8}>
      <VisualizerBars />
    </box>
  )
} 