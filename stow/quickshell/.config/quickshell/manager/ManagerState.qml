import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var snapshot: ({})
    property string error: ""
    property var inventory: ({})
    readonly property var catalog: snapshot.catalog || []
    readonly property var prompt: snapshot.prompt || ({})
    readonly property var overview: inventory.checked > (snapshot.overview?.checked || 0) ? inventory : snapshot.overview || inventory
    readonly property var details: snapshot.details || ({})
    property string answeredPromptId: ""
    readonly property bool answering: answerProcess.running || (!!prompt.id && answeredPromptId === prompt.id)
    property bool starting: false
    property string pendingId: ""
    property double pendingSince: 0
    property int logOffset: -1
    property string logPage: ""
    readonly property bool busy: starting || pendingId.length > 0 || !!snapshot.busy
    readonly property string backend: Qt.resolvedUrl("../assets/scripts/workspace-manager.py").toString().replace(/^file:\/\//, "")
    readonly property var updates: snapshot.updates || ({})
    readonly property var cleanup: snapshot.cleanup || ({})
    readonly property var temporary: snapshot.temporary || []
    readonly property var job: snapshot.job || ({})
    readonly property string activity: logOffset >= 0 ? logPage : snapshot.log || "Your operation details will appear here."

    function olderOutput() {
        const offset = Math.max(0, (logOffset < 0 ? (snapshot.logSize || 0) - 24000 : logOffset) - 24000)
        logProcess.command = ["python3", backend, "log", JSON.stringify({offset: offset})]
        logProcess.running = true
    }

    function newerOutput() {
        if (logOffset + 48000 >= (snapshot.logSize || 0)) { logOffset = -1; return }
        logProcess.command = ["python3", backend, "log", JSON.stringify({offset: logOffset + 24000})]
        logProcess.running = true
    }

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true
    }

    function answer(response) {
        if (answering || !prompt.id)
            return
        error = ""
        answeredPromptId = prompt.id
        answerProcess.command = ["python3", backend, "respond", JSON.stringify(Object.assign({id: prompt.id, jobId: prompt.jobId}, response))]
        answerProcess.running = true
    }

    function refreshOverview() {
        if (!overviewProcess.running)
            overviewProcess.running = true
    }

    function start(request) {
        if (busy)
            return
        error = ""
        starting = true
        logOffset = -1
        startProcess.command = ["python3", backend, "start", JSON.stringify(request)]
        startProcess.running = true
    }

    function size(bytes) {
        if (bytes === undefined || bytes === null)
            return "Not scanned"
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(0) + " KiB"
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(0) + " MiB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB"
    }

    function date(timestamp) {
        return timestamp ? new Date(timestamp * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat) : "Never checked"
    }

    property Process statusProcess: Process {
        command: ["python3", root.backend, "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.error) {
                        root.error = data.error
                        return
                    }
                    const finished = root.snapshot.busy && !data.busy
                    root.snapshot = data
                    if (finished) root.refreshOverview()
                    if (data.job?.id === root.pendingId)
                        root.pendingId = ""
                    else if (root.pendingId && !data.busy && Date.now() - root.pendingSince > 10000) {
                        root.pendingId = ""
                        root.error = "The operation could not start. Review Activity and try again."
                    }
                } catch (exception) {
                    root.error = "Unable to read workspace status: " + exception
                }
            }
        }
        stderr: StdioCollector {}
    }

    property Process startProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.error)
                        root.error = data.error
                    else {
                        root.pendingId = data.id
                        root.pendingSince = Date.now()
                    }
                } catch (exception) {
                    root.error = "Unable to start operation: " + exception
                }
                root.starting = false
                root.refresh()
            }
        }
        stderr: StdioCollector {}
    }

    property Process logProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.error) root.error = data.error
                    else { root.logPage = data.text; root.logOffset = data.offset }
                } catch (exception) { root.error = "Unable to read log: " + exception }
            }
        }
        stderr: StdioCollector {}
    }

    property Process overviewProcess: Process {
        command: ["python3", root.backend, "overview"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.error) root.error = data.error
                    else root.inventory = data
                } catch (exception) { root.error = "Unable to read system overview: " + exception }
            }
        }
        stderr: StdioCollector {}
    }

    property Process answerProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data.error) { root.error = data.error; root.answeredPromptId = "" }
                } catch (exception) { root.error = "Unable to answer: " + exception; root.answeredPromptId = "" }
                root.refresh()
            }
        }
        stderr: StdioCollector {}
    }

    property Timer poll: Timer {
        interval: root.busy ? 1000 : 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
