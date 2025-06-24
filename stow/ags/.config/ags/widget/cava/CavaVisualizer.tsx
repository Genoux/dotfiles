import { Gtk } from "astal/gtk3"
import { bind } from "astal"
import { getCurrentMediaSource } from "../mediaplayer/utils"
import Hyprland from "gi://AstalHyprland"
import { cavaData, calculateGradientOpacity } from "./Service"

function VisualizerBars() {
  return (
    <box 
      className="cava-bars" 
      spacing={2}
      heightRequest={16} // Fixed height that fits within the 24px bar
      valign={Gtk.Align.CENTER} // Center within the bar
    >
      {bind(cavaData).as(bars =>
        bars.map((height, index) => {
          // Use service utility for gradient calculation
          const opacity = calculateGradientOpacity(index, bars.length)
          
          return (
            <box
              className="cava-bar"
              widthRequest={3}
              heightRequest={Math.min(height, 16)}
              valign={Gtk.Align.CENTER}
              css={`opacity: ${opacity.toFixed(2)};`}
            />
          )
        })
      )}
    </box>
  )
}

function handleCavaClick() {
  try {
    const mediaSource = getCurrentMediaSource()
    const hypr = Hyprland.get_default()
    
    if (mediaSource) {
      console.log(`Opening media source: ${mediaSource}`)
      hypr.dispatch("focuswindow", `class:${mediaSource}`)
    } else {
      console.log("No active media player found, trying fallback apps")
      // Fallback: try to open common music apps
      const musicApps = ["spotify", "rhythmbox", "vlc", "audacious"]
      for (const app of musicApps) {
        try {
          hypr.dispatch("exec", app)
          break
        } catch (e) {
          continue
        }
      }
    }
  } catch (error) {
    console.error("Failed to open media source:", error)
  }
}

export default function CavaVisualizer() {
  return (
    <eventbox
      onButtonPressEvent={() => {
        handleCavaClick()
        return true
      }}
      cursor="pointer"
    >
      <box className="cava-island" spacing={8} heightRequest={16} valign={Gtk.Align.CENTER}>
        <VisualizerBars />
      </box>
    </eventbox>
  )
}