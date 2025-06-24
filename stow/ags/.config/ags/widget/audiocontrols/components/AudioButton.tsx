import { bind, Variable } from "astal"
import Wp from "gi://AstalWp"
import { getVolumeIcon } from "../utils"

export default function AudioButton() {
    const audio = Wp.get_default()
    const speaker = audio?.get_default_speaker()

    if (!speaker) {
        return (
            <button className="audio-button">
                <icon icon="audio-volume-muted-symbolic" />
            </button>
        )
    }

    // Derive icon from both volume and mute state
    const iconName = Variable.derive([
        bind(speaker, "volume"),
        bind(speaker, "mute")
    ], (volume, mute) => getVolumeIcon(volume, mute))

    return (
        <button
            className={bind(speaker, "mute").as(muted => 
                muted ? "audio-button active" : "audio-button"
            )}
            onClicked={() => {
                speaker.mute = !speaker.mute
            }}
        >
            <icon icon={bind(iconName)} />
        </button>
    )
} 