import QtQuick
import Quickshell
pragma Singleton

Singleton {
    // extra dark overlay, 0 = none
    // ms; slides off the top to reveal desktop
    // lock surface fade out on unlock

    readonly property color transparent: "transparent"
    // ── Wallpaper / dim ───────────────────────────────────────────────────────
    readonly property string wallpaperPath: Quickshell.env("HOME") + "/.config/hypr/wallpapers/current/current_wallpaper.jpg"
    readonly property real wallpaperDimOpacity: 0
    // full-screen dim overlay, 0 = none
    // ── Clock ─────────────────────────────────────────────────────────────────
    readonly property string fontDisplay: "SF Pro Display"
    readonly property int clockFontSize: 120
    readonly property real clockLetterSpacing: -2 // em units; negative tightens
    readonly property string clockStyleName: "Bold"
    readonly property int clockFontWeight: Font.Bold
    readonly property bool clockItalic: false
    readonly property int dateTimeTopOffset: 100 // px from screen top to date
    readonly property color clockColor: Qt.rgba(1, 1, 1, 0.8)
    // ── Date ──────────────────────────────────────────────────────────────────
    readonly property int dateFontSize: 26
    readonly property real dateLetterSpacing: 2 // em units; positive spreads
    readonly property string dateStyleName: "Medium"
    readonly property int dateFontWeight: Font.Medium // Thin/Light/Normal/Medium/Bold
    readonly property bool dateItalic: false
    readonly property int dateTimeSpacing: -10 // px gap between date and time
    readonly property color dateColor: Qt.rgba(1, 1, 1, 0.5)
    // ── Password input ────────────────────────────────────────────────────────
    readonly property string fontInput: "SF Pro Display"
    readonly property int inputWidth: 180
    readonly property int inputHeight: 40
    readonly property int inputRadius: 10
    // corner radius px; 0 = auto capsule (half of pill height)
    readonly property int inputOutline: 1
    readonly property int inputBottomOffset: 100 // px from screen bottom to input stack
    readonly property color inputOuterColor: transparent
    readonly property color inputBorderColor: transparent
    readonly property color inputInnerColor: Qt.rgba(1, 1, 1, 0.1)
    readonly property color inputFontColor: Qt.rgba(200 / 255, 200 / 255, 200 / 255, 1)
    // password dots
    readonly property int inputDotSize: 10
    // diameter px
    readonly property int inputDotSpacing: 3
    // gap between dots px
    // password caret
    readonly property int inputCaretWidth: 1
    // width px
    readonly property int inputCaretHeight: 18
    // height px
    // ── Collapsed lock pill ─────────────────────────────────────────────────────
    readonly property int collapsedSize: inputHeight
    // circle diameter when collapsed
    readonly property string lockGlyph: "\uf023"
    // nerd-font padlock
    readonly property string lockGlyphFont: "JetBrainsMono Nerd Font"
    readonly property int lockGlyphSize: 20
    readonly property color lockGlyphColor: Qt.rgba(1, 1, 1, 0.7)
    readonly property int idleCollapseMs: 5000 // collapse back to lock after focus loss (only when empty)
    readonly property int morphDuration: 150 // circle <-> input morph
    readonly property int glyphFadeDuration: 200 // lock-glyph fade in/out speed
    readonly property int cursorRevealDelay: 100 // ms after morph before caret appears
    readonly property int caretBlinkInterval: 530 // ms between blink peaks
    readonly property int caretBlinkFadeDuration: 150 // ms; softens on/off transitions
    readonly property color failureColor: Qt.rgba(1, 0.18, 0.18, 0.9) // wrong-password border
    // ── Animation ─────────────────────────────────────────────────────────────
    readonly property int fadeInDuration: 500
    // lock surface fade in over desktop
    readonly property int fadeOutDuration: 300
}
