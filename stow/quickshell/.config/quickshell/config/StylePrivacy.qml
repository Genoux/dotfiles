import QtQuick
import Quickshell
pragma Singleton

Singleton {
    readonly property color webcamFill: Qt.rgba(0.3, 0.27, 0.77, 0.37)
    readonly property color webcamBorder: Qt.rgba(0.34, 0.28, 0.77, 0.87)
    readonly property color micFill: Qt.rgba(0.2, 1, 0.61, 0.2)
    readonly property color micBorder: Qt.rgba(0.22, 0.99, 0.58, 0.37)
    readonly property color screenFill: Qt.rgba(1, 0.43, 1, 0.2)
    readonly property color screenBorder: Qt.rgba(0.69, 0.33, 0.87, 0.87)
}
