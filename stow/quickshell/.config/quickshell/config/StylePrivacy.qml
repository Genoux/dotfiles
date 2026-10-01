import QtQuick
import Quickshell
pragma Singleton

// Fixed signal colours rather than theme tokens: camera green and mic orange
// must read the same under every wallpaper palette, as they do on macOS.
Singleton {
    readonly property int dotSize: 7
    readonly property color camera: "#30D158"
    readonly property color microphone: "#FF9F0A"
    readonly property color screen: "#BF5AF2"
}
