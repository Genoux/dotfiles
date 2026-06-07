pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool webcam: false
    property bool mic: false
    property bool screenrecord: false
    readonly property bool anyActive: webcam || mic || screenrecord

    Process {
        command: ["bash", "-lc", `
            check_webcam() {
                fuser /dev/video* 2>/dev/null | grep -q . && echo 1 || echo 0
            }

            check_mic() {
                if command -v pactl >/dev/null 2>&1; then
                    pactl list source-outputs 2>/dev/null | grep -q 'target.object = "alsa_input' && echo 1 && return
                fi
                echo 0
            }

            check_webcam_mic() {
                local webcam_active="$1"
                if [ "$webcam_active" = "1" ] && command -v pactl >/dev/null 2>&1; then
                    pactl list sources short 2>/dev/null | grep -qi "webcam\\|camera\\|video" && echo 1 && return
                fi
                echo 0
            }

            check_screenrecord() {
                pgrep -x wl-screenrec >/dev/null 2>&1 && echo 1 && return
                pgrep -x wf-recorder >/dev/null 2>&1 && echo 1 && return
                pgrep -x obs >/dev/null 2>&1 && echo 1 && return
                pgrep -x gpu-screen-recorder >/dev/null 2>&1 && echo 1 && return
                pgrep -x kooha >/dev/null 2>&1 && echo 1 && return
                pgrep -f "^[^ ]*wl-screenrec" >/dev/null 2>&1 && echo 1 && return
                pgrep -f "^[^ ]*wf-recorder" >/dev/null 2>&1 && echo 1 && return
                echo 0
            }

            last_state=""
            while true; do
                cur_webcam=$(check_webcam)
                cur_mic=$(check_mic)
                cur_webcam_mic=$(check_webcam_mic "$cur_webcam")
                cur_screen=$(check_screenrecord)

                if [ "$cur_mic" = "1" ] || [ "$cur_webcam_mic" = "1" ]; then
                    final_mic=1
                else
                    final_mic=0
                fi

                state="$cur_webcam:$final_mic:$cur_screen"
                if [ "$state" != "$last_state" ]; then
                    printf '%s\\n' "$state"
                    last_state="$state"
                fi

                sleep 1
            done
        `]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const parts = data.trim().split(":")
                if (parts.length !== 3) {
                    return
                }

                root.webcam = parts[0] === "1"
                root.mic = parts[1] === "1"
                root.screenrecord = parts[2] === "1"
            }
        }
    }
}
