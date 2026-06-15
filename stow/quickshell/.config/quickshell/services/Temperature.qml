pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property string value: "--°C"

    function refresh() {
        tempProcess.running = true
    }

    Process {
        id: tempProcess

        command: ["bash", "-lc", `
            cpu=0
            gpu=0

            for name in /sys/class/hwmon/hwmon*/name; do
                [ -r "$name" ] || continue
                label=$(cat "$name")
                case "$label" in
                    *k10temp*|*coretemp*|*cpu*)
                        dir=\${name%/name}
                        for temp in "$dir"/temp*_input; do
                            [ -r "$temp" ] && cpu=$(( $(cat "$temp") / 1000 )) && break
                        done
                        break
                        ;;
                esac
            done

            for temp in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
                [ -r "$temp" ] && gpu=$(( $(cat "$temp") / 1000 )) && break
            done

            if [ "$gpu" -eq 0 ] && command -v nvidia-smi >/dev/null 2>&1; then
                gpu=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
            fi

            if [ "\${cpu:-0}" -gt 0 ] && [ "\${gpu:-0}" -gt 0 ]; then
                avg=$(( (cpu + gpu) / 2 ))
            else
                avg=$(( cpu > gpu ? cpu : gpu ))
            fi

            if [ "\${avg:-0}" -gt 0 ]; then
                printf '%s°C\\n' "$avg"
            else
                printf '--°C\\n'
            fi
        `]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.value = this.text.trim() || "--°C"
        }
    }

    Timer {
        interval: StyleTokens.pollIntervalSlow
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
