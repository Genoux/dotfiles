pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    property bool active: false
    property bool loaded: false
    property real cpuUsage: 0
    property real memoryUsage: 0
    property real diskUsage: 0
    property real memoryUsedBytes: 0
    property real memoryTotalBytes: 0
    property real diskUsedBytes: 0
    property real diskTotalBytes: 0
    property int uptimeSeconds: 0
    property int userId: -1
    property int pendingKillPid: -1
    property var processes: []

    readonly property string uptime: formatUptime(uptimeSeconds)
    readonly property string memoryDetail: formatBytes(memoryUsedBytes) + " / " + formatBytes(memoryTotalBytes)
    readonly property string diskDetail: formatBytes(diskUsedBytes) + " / " + formatBytes(diskTotalBytes)

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Number(value) || 0))
    }

    function formatBytes(bytes) {
        const value = Number(bytes) || 0
        if (value <= 0)
            return "--"

        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        const unit = Math.min(units.length - 1, Math.floor(Math.log(value) / Math.log(1024)))
        const scaled = value / Math.pow(1024, unit)
        return (scaled >= 10 || unit === 0 ? scaled.toFixed(0) : scaled.toFixed(1)) + " " + units[unit]
    }

    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)

        if (days > 0)
            return days + "d " + hours + "h"
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return Math.max(1, minutes) + "m"
    }

    function refresh() {
        if (!sampleProcess.running)
            sampleProcess.running = true
    }

    function killProcess(pid) {
        const numericPid = Math.floor(Number(pid))
        if (numericPid <= 1 || numericPid === Quickshell.processId || terminateProcess.running)
            return

        pendingKillPid = numericPid
        terminateProcess.exec(["kill", "-TERM", "--", String(numericPid)])
    }

    onActiveChanged: {
        if (active)
            refresh()
    }

    Process {
        id: sampleProcess

        // Two close /proc/stat snapshots produce a current CPU reading. `ps`
        // lifetime averages are sufficient for ranking the compact process list;
        // the panel is a glanceable overview, not a full btop replacement.
        command: ["bash", "-lc", `
            export LC_ALL=C

            read -r idle_a total_a < <(awk '/^cpu / { idle=$5+$6; for (i=2; i<=NF; i++) total+=$i; print idle, total; exit }' /proc/stat)
            sleep 0.15
            read -r idle_b total_b < <(awk '/^cpu / { idle=$5+$6; for (i=2; i<=NF; i++) total+=$i; print idle, total; exit }' /proc/stat)

            delta_total=$((total_b - total_a))
            delta_idle=$((idle_b - idle_a))
            if (( delta_total > 0 )); then
                cpu=$((100 * (delta_total - delta_idle) / delta_total))
            else
                cpu=0
            fi

            read -r mem_total mem_available < <(awk '
                /^MemTotal:/ { total=$2 }
                /^MemAvailable:/ { available=$2 }
                END { print total * 1024, available * 1024 }
            ' /proc/meminfo)

            read -r disk_total disk_available < <(df -B1 --output=size,avail / | awk 'NR == 2 { print $1, $2 }')
            uptime=$(cut -d. -f1 /proc/uptime)
            user_id=$(id -u)

            printf 'stats\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \
                "$cpu" "$mem_total" "$mem_available" "$disk_total" "$disk_available" "$uptime" "$user_id"

            ps -eo pid=,uid=,pcpu=,pmem=,comm= | awk '
                {
                    line=$0
                    pid=$1
                    uid=$2
                    cpu=$3
                    memory=$4
                    sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", line)
                    printf "process\\t%s\\t%s\\t%s\\t%s\\t%s\\n", pid, uid, cpu, memory, line
                }
            '
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const nextProcesses = []
                const lines = this.text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const fields = lines[i].split("\t")
                    if (fields[0] === "stats" && fields.length >= 8) {
                        const memoryTotal = Number(fields[2]) || 0
                        const memoryAvailable = Number(fields[3]) || 0
                        const diskTotal = Number(fields[4]) || 0
                        const diskAvailable = Number(fields[5]) || 0

                        root.cpuUsage = root.clampPercent(fields[1])
                        root.memoryTotalBytes = memoryTotal
                        root.memoryUsedBytes = Math.max(0, memoryTotal - memoryAvailable)
                        root.memoryUsage = memoryTotal > 0 ? root.clampPercent(root.memoryUsedBytes / memoryTotal * 100) : 0
                        root.diskTotalBytes = diskTotal
                        root.diskUsedBytes = Math.max(0, diskTotal - diskAvailable)
                        root.diskUsage = diskTotal > 0 ? root.clampPercent(root.diskUsedBytes / diskTotal * 100) : 0
                        root.uptimeSeconds = Number(fields[6]) || 0
                        root.userId = Number(fields[7])
                    } else if (fields[0] === "process" && fields.length >= 6) {
                        const pid = Number(fields[1]) || -1
                        const ownerId = Number(fields[2])
                        nextProcesses.push({
                            pid: pid,
                            cpu: Number(fields[3]) || 0,
                            memory: Number(fields[4]) || 0,
                            name: fields.slice(5).join(" ") || "Unknown",
                            killable: ownerId === root.userId && pid > 1 && pid !== Quickshell.processId,
                        })
                    }
                }

                root.processes = nextProcesses
                root.loaded = true
            }
        }
    }

    Process {
        id: terminateProcess

        onExited: {
            root.pendingKillPid = -1
            refreshAfterKill.restart()
        }
    }

    Timer {
        id: refreshAfterKill

        interval: StyleTokens.easeDurationNormal
        onTriggered: root.refresh()
    }

    Timer {
        interval: StyleTokens.pollIntervalFast * 2
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
