import Quickshell.Io
import QtQuick
import qs.components

Pill {
    id: root

    property var runCommand: []
    property var clickCommand: []
    property int interval: 1000
    property var formatOutput: (output) => output.trim()

    interactive: clickCommand.length > 0

    Process {
        id: commandProcess

        command: root.runCommand
        running: root.runCommand.length > 0

        stdout: StdioCollector {
            onStreamFinished: root.text = root.formatOutput(this.text)
        }
    }

    Process {
        id: clickProcess

        command: root.clickCommand
    }

    Timer {
        interval: root.interval
        running: root.runCommand.length > 0 && root.interval > 0
        repeat: true
        onTriggered: commandProcess.running = true
    }

    onClicked: clickProcess.running = true
}
