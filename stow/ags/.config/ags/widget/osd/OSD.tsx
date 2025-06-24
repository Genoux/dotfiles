import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import { timeout } from "astal/time"
import Variable from "astal/variable"
import Wp from "gi://AstalWp"
import { getVolumeIcon, clampVolume, isOSDSuppressed } from "../audiocontrols/utils"

function OnScreenProgress({ visible }: { visible: Variable<boolean> }) {
  const wp = Wp.get_default()
  let speaker: Wp.Endpoint | null = null

  // Safely get the speaker
  try {
    speaker = wp?.get_default_speaker() ?? null
  } catch (error) {
    console.error("Failed to get WirePlumber speaker:", error)
  }

  const iconName = Variable("audio-volume-medium-symbolic")
  const value = Variable(0)
  const label = Variable("0%")

  let startupComplete = false
  timeout(100, () => { startupComplete = true })

  let count = 0
  function show(v: number, icon: string, labelText?: string) {
    if (!startupComplete) return // Don't show during startup

    // Check if OSD is suppressed (e.g., during manual slider dragging)
    if (isOSDSuppressed()) {
      console.log("OSD suppressed, not showing")
      return
    }

    // Clamp the volume for display purposes
    const clampedVolume = clampVolume(v)
    console.log("OSD show:", clampedVolume, icon, labelText)
    if (clampedVolume > 1.0) {
      return
    }
    visible.set(true)
    value.set(clampedVolume)
    iconName.set(icon)
    
    // Format percentage with consistent width
    const displayLabel = labelText || `${Math.floor(clampedVolume * 100).toString().padStart(3, ' ')}%`
    label.set(displayLabel)

    count++
    timeout(2000, () => {
      count--
      if (count === 0) visible.set(false)
    })
  }

  return (
    <revealer
      setup={(self) => {
        if (speaker) {
          console.log("Setting up OSD with speaker:", speaker.description)

          // Volume changes
          self.hook(speaker, "notify::volume", () => {
            const vol = speaker!.volume
            const icon = getVolumeIcon(vol, speaker!.mute)
            show(vol, icon)
          })

          // Mute changes  
          self.hook(speaker, "notify::mute", () => {
            const vol = speaker!.mute ? 0 : speaker!.volume
            const icon = getVolumeIcon(speaker!.volume, speaker!.mute)
            show(vol, icon, speaker!.mute ? "Muted" : undefined)
          })
        } else {
          console.warn("No WirePlumber speaker available for OSD")
        }
      }}
      revealChild={visible()}
      transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
      transitionDuration={200}
      widthRequest={250}
      heightRequest={70}
    >
      <box className="osd-container" spacing={10}>
        <icon
          className="osd-icon"
          icon={iconName()}
        />
        <slider
          className="osd-slider"
          hexpand
          value={value()}
          max={1.0}
          min={0.0}
          sensitive={false}
        />
        <label
          className="osd-label"
          label={label()}
          widthRequest={45}
          halign={Gtk.Align.END}
        />
      </box>
    </revealer>
  )
}

export default function OSD(monitor: Gdk.Monitor) {
  const visible = Variable(false)

  return (
    <window
      gdkmonitor={monitor}
      className="OSDWindow"
      namespace="osd"
      application={App}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.NONE}
      anchor={Astal.WindowAnchor.BOTTOM}
      exclusivity={Astal.Exclusivity.NORMAL}
      visible={false}
      canFocus={false}
      setup={(self) => {
        visible.subscribe((v) => {
          self.visible = v
        })
      }}
    >
      <eventbox
        onClick={() => visible.set(false)}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
      >
        <OnScreenProgress visible={visible} />
      </eventbox>
    </window>
  )
} 