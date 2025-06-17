import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import { timeout } from "astal/time"
import Variable from "astal/variable"
import Wp from "gi://AstalWp"

function OnScreenProgress({ visible }: { visible: Variable<boolean> }) {
    const speaker = Wp.get_default()?.get_default_speaker()

    const iconName = Variable("")
    const value = Variable(0)
    const label = Variable("0%")

    let startupComplete = false
    timeout(50, () => { startupComplete = true })

    let count = 0
    function show(v: number, icon: string, labelText?: string) {
        if (!startupComplete) return // Don't show during startup
        
        visible.set(true)
        value.set(v)
        iconName.set(icon)
        label.set(labelText || `${Math.floor(v * 100)}%`)
        
        count++
        timeout(2000, () => {
            count--
            if (count === 0) visible.set(false)
        })
    }

    return (
        <revealer
            setup={(self) => {
                // Volume changes
                if (speaker) {
                    self.hook(speaker, "notify::volume", () => {
                        const vol = speaker.volume
                        const icon = speaker.volumeIcon || "audio-volume-medium-symbolic"
                        show(vol, icon)
                    })
                    
                    self.hook(speaker, "notify::mute", () => {
                        const vol = speaker.mute ? 0 : speaker.volume
                        const icon = speaker.mute ? "audio-volume-muted-symbolic" : (speaker.volumeIcon || "audio-volume-medium-symbolic")
                        show(vol, icon, speaker.mute ? "Muted" : undefined)
                    })
                }
            }}
            revealChild={visible()}
            transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
            transitionDuration={1200}
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
                    sensitive={false}
                />
                <label 
                    className="osd-label"
                    label={label()} 
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