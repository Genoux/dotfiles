pragma Singleton

import QtQuick

// Theme colors matching AGS configuration
QtObject {
    // Text colors
    readonly property color textPrimary: Qt.rgba(250/255, 250/255, 250/255, 0.96)
    readonly property color textSecondary: Qt.rgba(220/255, 220/255, 220/255, 0.82)
    readonly property color textTertiary: Qt.rgba(180/255, 180/255, 180/255, 0.68)
    readonly property color textDisabled: Qt.rgba(120/255, 120/255, 120/255, 0.48)
    
    // Background colors
    readonly property color bgPrimary: Qt.rgba(25/255, 25/255, 28/255, 0.96)
    readonly property color bgSecondary: Qt.rgba(32/255, 32/255, 36/255, 0.9)
    readonly property color bgTertiary: Qt.rgba(28/255, 28/255, 34/255, 0.6)
    readonly property color bgQuaternary: Qt.rgba(28/255, 28/255, 34/255, 0.5)
    readonly property color bgTranslucent: Qt.rgba(30/255, 30/255, 34/255, 0.31)
    
    // Surface colors
    readonly property color surfacePrimary: Qt.rgba(30/255, 30/255, 34/255, 0.94)
    readonly property color surfaceSecondary: Qt.rgba(38/255, 38/255, 42/255, 0.90)
    
    // Border colors
    readonly property color borderPrimary: Qt.rgba(255/255, 255/255, 255/255, 0.015)
    readonly property color borderSecondary: Qt.rgba(255/255, 255/255, 255/255, 0.03)
    readonly property color borderTertiary: Qt.rgba(255/255, 255/255, 255/255, 0.05)
    readonly property color borderFocus: Qt.rgba(255/255, 255/255, 255/255, 0.06)
    
    // Accent colors
    readonly property color accentPrimary: Qt.rgba(180/255, 180/255, 180/255, 0.85)
    readonly property color accentSecondary: Qt.rgba(160/255, 160/255, 160/255, 0.65)
    readonly property color accentHover: Qt.rgba(200/255, 200/255, 200/255, 0.90)
    readonly property color accentMuted: Qt.rgba(140/255, 140/255, 140/255, 0.35)
    
    // State colors
    readonly property color stateHover: Qt.rgba(255/255, 255/255, 255/255, 0.025)
    readonly property color stateActive: Qt.rgba(180/255, 180/255, 180/255, 0.12)
    
    // Status colors
    readonly property color warning: Qt.rgba(255/255, 200/255, 80/255, 0.9)
    readonly property color error: Qt.rgba(255/255, 100/255, 100/255, 0.85)
    readonly property color success: Qt.rgba(100/255, 200/255, 100/255, 0.8)
    readonly property color info: Qt.rgba(150/255, 150/255, 200/255, 0.8)
    
    // Utility colors
    readonly property color white: Qt.rgba(1, 1, 1, 1)
    readonly property color black: Qt.rgba(0, 0, 0, 1)
    readonly property color whiteTranslucent: Qt.rgba(255/255, 255/255, 255/255, 0.05)
    readonly property color blackTranslucent: Qt.rgba(0, 0, 0, 0.05)
}