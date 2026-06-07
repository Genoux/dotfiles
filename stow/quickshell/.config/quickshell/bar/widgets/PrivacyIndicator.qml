import Quickshell.Io
import QtQuick
import qs.components

Row {
    id: root

    property bool webcam: false
    property bool mic: false
    property bool screenrecord: false

    readonly property bool anyActive: webcam || mic || screenrecord

    visible: anyActive
    spacing: 2

    Process {
        id: monitorProcess

        command: ["bash", "-lc", `
            check_webcam() {
                fuser /dev/video* 2>/dev/null | grep -q . && echo 1 || echo 0
            }

            check_mic() {
                if command -v pactl &>/dev/null; then
                    pactl list source-outputs 2>/dev/null | grep -q 'target.object = "alsa_input' && echo 1 && return
                fi
                echo 0
            }

            check_webcam_mic() {
                local webcam_active="$1"
                if [ "$webcam_active" = "1" ] && command -v pactl &>/dev/null; then
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

            cur_webcam=$(check_webcam)
            cur_mic=$(check_mic)
            cur_webcam_mic=$(check_webcam_mic "$cur_webcam")
            cur_screen=$(check_screenrecord)

            if [ "$cur_mic" = "1" ] || [ "$cur_webcam_mic" = "1" ]; then
                final_mic=1
            else
                final_mic=0
            fi

            printf '%s:%s:%s' "$cur_webcam" "$final_mic" "$cur_screen"
        `]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(":");
                if (parts.length !== 3) {
                    return;
                }

                root.webcam = parts[0] === "1";
                root.mic = parts[1] === "1";
                root.screenrecord = parts[2] === "1";
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: monitorProcess.running = true
    }

    PrivacyButton {
        visible: root.webcam
        iconName: "camera-video-symbolic"
        fillColor: "#344dff85"
        borderColor: "#5847c55e"
    }

    PrivacyButton {
        visible: root.mic
        iconName: "mic-on"
        fillColor: "#34ff9c32"
        borderColor: "#38fc9526"
    }

    PrivacyButton {
        visible: root.screenrecord
        iconName: "video-display-symbolic"
        fillColor: "#34ff6dff"
        borderColor: "#38af53de"
    }
}
