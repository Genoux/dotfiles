pragma Singleton

import QtQuick

// Theme constants matching AGS configuration
QtObject {
    // Spacing scale
    readonly property int spacingXs: 2
    readonly property int spacingSm: 4
    readonly property int spacingMd: 8
    readonly property int spacingLg: 12
    readonly property int spacingXl: 16
    readonly property int spacing2Xl: 24
    
    // Border radius scale
    readonly property int radiusXs: 4
    readonly property int radiusSm: 6
    readonly property int radiusMd: 8
    readonly property int radiusLg: 12
    readonly property int radiusXl: 16
    
    // Typography
    readonly property int fontSizeXs: 10
    readonly property int fontSizeSm: 12
    readonly property int fontSizeMd: 13
    readonly property int fontSizeLg: 14
    readonly property int fontSizeXl: 16
    
    // Border width
    readonly property int borderWidth: 1
    
    // Transitions (in milliseconds)
    readonly property int transitionFast: 50
    readonly property int transitionNormal: 200
    readonly property int transitionSlow: 300
    
    // Common measurements
    readonly property int separatorWidth: 1
    readonly property int barHeight: 28  // Central bar height control
}