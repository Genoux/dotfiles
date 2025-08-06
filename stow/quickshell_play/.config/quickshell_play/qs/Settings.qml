pragma Singleton
import QtQuick

QtObject {
    // Theme properties that match what the notification components expect
    readonly property QtObject Theme: QtObject {
        // Colors
        readonly property color accentPrimary: "#3b82f6"
        readonly property color textPrimary: "#ffffff"
        readonly property color textDisabled: "#6b7280"
        readonly property color backgroundPrimary: "#1f2937"
        
        // Fonts
        readonly property string fontFamily: "Inter, system-ui, sans-serif"
        readonly property int fontSizeSmall: 12
        readonly property int fontSizeCaption: 10
    }
}