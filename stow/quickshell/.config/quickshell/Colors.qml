pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The Material You palette, mapped onto base16 slots so the shells stay
// visually identical. matugen writes it as data on every wallpaper change
// (matugen/templates/quickshell-colors.json), and this file reads it live.
// Generating this file as QML instead made every wallpaper swap hot-reload the
// whole shell, closing whatever was open.
Singleton {
    // Background / surface ramp (darkest -> lightest)
    readonly property color base00: palette.base00 // Background: surface_dim
    readonly property color base01: palette.base01 // Surface: surface
    readonly property color base02: palette.base02 // Selection: surface_container_high
    readonly property color base03: palette.base03 // Lines / comments: surface_container_highest
    readonly property color base04: palette.base04 // Muted text: on_surface_variant
    readonly property color base05: palette.base05 // Text: on_surface
    readonly property color base06: palette.base06 // Light text: on_surface
    readonly property color base07: palette.base07 // Primary text: on_background

    // Accent colors (Material You roles mapped to base16 hue slots)
    readonly property color base08: palette.base08 // Red: error
    readonly property color base09: palette.base09 // Orange: secondary
    readonly property color base0A: palette.base0A // Yellow: tertiary
    readonly property color base0B: palette.base0B // Green: primary
    readonly property color base0C: palette.base0C // Cyan: tertiary_container
    readonly property color base0D: palette.base0D // Blue: primary
    readonly property color base0E: palette.base0E // Purple: secondary_container
    readonly property color base0F: palette.base0F // Mauve: tertiary

    // Read before the first frame, so nothing paints in the fallback first.
    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        // The fallback is a dark teal palette, shown only until matugen has
        // run once on a fresh machine.
        JsonAdapter {
            id: palette

            property string base00: "#0e1514"
            property string base01: "#0e1514"
            property string base02: "#252b2b"
            property string base03: "#2f3636"
            property string base04: "#bec9c7"
            property string base05: "#dde4e3"
            property string base06: "#dde4e3"
            property string base07: "#dde4e3"
            property string base08: "#ffb4ab"
            property string base09: "#b0ccca"
            property string base0A: "#b2c8e8"
            property string base0B: "#80d5d2"
            property string base0C: "#324863"
            property string base0D: "#80d5d2"
            property string base0E: "#324b4a"
            property string base0F: "#b2c8e8"
        }
    }
}
