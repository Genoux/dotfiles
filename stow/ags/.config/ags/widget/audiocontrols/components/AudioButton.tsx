import { bind } from "astal"
import Wp from "gi://AstalWp"

export default function AudioButton() {
    const audio = Wp.get_default()
    const speaker = audio?.get_default_speaker()

    return (
        <button
            className={speaker ? bind(speaker, "mute").as(muted => 
                muted ? "audio-button active" : "audio-button"
            ) : "audio-button"}
            onClicked={() => {
                if (speaker) {
                    speaker.mute = !speaker.mute
                }
            }}
        >
            <icon icon={speaker ? bind(speaker, "volumeIcon") : "audio-volume-muted-symbolic"} />
        </button>
    )
} 