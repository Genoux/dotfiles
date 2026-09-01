import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs
import qs.config
import qs.lock

// Root stays transparent so the unlock fade can reveal the live desktop, while
// fadeLayer provides a stable wallpaper-backed lock screen.
Item {
    id: root

    property bool enterStarted: false
    property bool inputHovered: false
    property bool cursorReady: false
    property real caretBlinkOpacity: 1
    // Collapsed = circle with lock glyph; expanded = full password field.
    // Opens on hover or as soon as there is text; folds back when neither holds.
    readonly property bool inputExpanded: inputHovered || passwordBox.text.length > 0
    readonly property bool caretActive: inputExpanded && cursorReady && !widthAnim.running
    required property LockContext context

    function startEnter() {
        if (root.enterStarted)
            return ;

        root.enterStarted = true;
        fadeLayer.opacity = 0;
        fadeIn.start();
    }

    function scheduleCursorReveal() {
        cursorReady = false;
        cursorRevealTimer.restart();
    }

    onHeightChanged: startEnter()
    onInputExpandedChanged: {
        if (inputExpanded)
            scheduleCursorReveal();
        else
            cursorReady = false;
    }
    onCaretActiveChanged: {
        if (caretActive)
            caretBlinkOpacity = 1;

    }
    // Keep keyboard focus on the field at all times so typing expands the pill
    // even before it is hovered.
    Component.onCompleted: {
        Qt.callLater(startEnter);
        passwordBox.forceActiveFocus();
    }

    Timer {
        id: cursorRevealTimer

        interval: StyleLock.cursorRevealDelay
        onTriggered: {
            if (root.inputExpanded && !widthAnim.running)
                root.cursorReady = true;

        }
    }

    Timer {
        id: caretBlinkTimer

        interval: StyleLock.caretBlinkInterval
        repeat: true
        running: root.caretActive
        onTriggered: root.caretBlinkOpacity = root.caretBlinkOpacity > 0.5 ? 0 : 1
    }

    Item {
        id: fadeLayer

        anchors.fill: parent
        opacity: 0
        // Composite the lock UI as one scene while it fades. Without a layer,
        // the partially transparent text and dim overlay lose contrast at
        // different rates and make the foreground appear to vanish first.
        layer.enabled: fadeIn.running || fadeOut.running

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: wallpaper

                anchors.fill: parent
                anchors.margins: -StyleLock.wallpaperBlurMax
                source: StyleLock.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: wallpaper
                source: wallpaper
                blurEnabled: true
                blur: StyleLock.wallpaperBlur
                blurMax: StyleLock.wallpaperBlurMax
                autoPaddingEnabled: false
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.base00
            opacity: StyleLock.wallpaperDimOpacity
        }

        // ── Date & time ───────────────────────────────────────────────────────
        Item {
            id: dateTime

            property var date: new Date()

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: StyleLock.dateTimeTopOffset

            Timer {
                running: true
                repeat: true
                interval: 1000
                onTriggered: dateTime.date = new Date()
            }

            Column {
                id: dateTimeColumn

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: StyleLock.dateTimeSpacing

                Label {
                    id: dateLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    renderType: Text.NativeRendering
                    font.family: StyleLock.fontDisplay
                    font.styleName: StyleLock.dateStyleName
                    font.pixelSize: StyleLock.dateFontSize
                    font.weight: StyleLock.dateFontWeight
                    font.italic: StyleLock.dateItalic
                    font.letterSpacing: StyleLock.dateLetterSpacing
                    color: StyleLock.dateColor
                    text: Qt.formatDateTime(dateTime.date, "dddd, MMMM d")
                }

                Label {
                    id: clock

                    anchors.horizontalCenter: parent.horizontalCenter
                    renderType: Text.NativeRendering
                    font.family: StyleLock.fontDisplay
                    font.styleName: StyleLock.clockStyleName
                    font.pixelSize: StyleLock.clockFontSize
                    font.weight: StyleLock.clockFontWeight
                    font.italic: StyleLock.clockItalic
                    font.letterSpacing: StyleLock.clockLetterSpacing
                    color: StyleLock.clockColor
                    text: Qt.formatDateTime(dateTime.date, "HH:mm")
                }

            }

        }

        // ── Password input ────────────────────────────────────────────────────
        Item {
            id: inputHost

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: StyleLock.inputBottomOffset
            width: StyleLock.inputWidth
            height: StyleLock.inputHeight

            Item {
                id: inputPill

                readonly property real pillRadius: Math.min(StyleLock.inputRadius > 0 ? StyleLock.inputRadius : Math.min(width, height) / 2, width / 2, height / 2)

                anchors.centerIn: parent
                height: StyleLock.inputHeight
                width: root.inputExpanded ? StyleLock.inputWidth : StyleLock.collapsedSize

                Rectangle {
                    anchors.fill: parent
                    radius: inputPill.pillRadius
                    color: StyleLock.inputInnerColor
                    border.width: StyleLock.inputOutline
                    border.color: root.context.showFailure ? StyleLock.failureColor : StyleLock.inputBorderColor
                }

                Behavior on width {
                    NumberAnimation {
                        id: widthAnim

                        duration: StyleLock.morphDuration
                        easing.type: Easing.OutCubic
                        onRunningChanged: {
                            if (widthAnim.running) {
                                root.cursorReady = false;
                                cursorRevealTimer.stop();
                            } else if (root.inputExpanded) {
                                root.scheduleCursorReveal();
                            }
                        }
                    }

                }

            }

            // Glyph sits on the fixed host center, not inside the morphing pill.
            Label {
                anchors.centerIn: parent
                text: StyleLock.lockGlyph
                font.family: StyleLock.lockGlyphFont
                font.pixelSize: StyleLock.lockGlyphSize
                color: root.context.showFailure ? StyleLock.failureColor : StyleLock.lockGlyphColor
                visible: opacity > 0
                opacity: (!root.inputExpanded && !widthAnim.running) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleLock.glyphFadeDuration
                    }

                }

            }

            Item {
                id: passwordField

                readonly property int dotCount: passwordBox.text.length
                readonly property real dotsRowWidth: dotCount > 0 ? dotCount * StyleLock.inputDotSize + (dotCount - 1) * StyleLock.inputDotSpacing : 0

                anchors.centerIn: parent
                width: StyleLock.inputWidth - StyleLock.inputOutline * 2
                height: StyleLock.inputHeight - StyleLock.inputOutline * 2
                // Stays visible (opacity handles hiding) so the TextInput can
                // hold keyboard focus while the pill is collapsed.
                opacity: (root.inputExpanded && !widthAnim.running) ? 1 : 0

                Row {
                    id: passwordDots

                    anchors.verticalCenter: parent.verticalCenter
                    x: (passwordField.width - passwordField.dotsRowWidth) / 2
                    spacing: StyleLock.inputDotSpacing
                    visible: passwordField.dotCount > 0

                    Repeater {
                        model: passwordField.dotCount

                        Rectangle {
                            width: StyleLock.inputDotSize
                            height: StyleLock.inputDotSize
                            radius: width / 2
                            color: StyleLock.inputFontColor
                        }

                    }

                }

                TextInput {
                    id: passwordBox

                    anchors.fill: parent
                    clip: true
                    enabled: !root.context.unlockInProgress
                    echoMode: TextInput.NoEcho
                    inputMethodHints: Qt.ImhSensitiveData
                    color: StyleLock.transparent
                    font.pixelSize: 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: false
                    cursorVisible: false
                    onTextChanged: root.context.currentText = text
                    onAccepted: root.context.tryUnlock()
                    onActiveFocusChanged: {
                        cursorVisible = false;
                        if (!activeFocus)
                            forceActiveFocus();
                    }

                    Connections {
                        function onCurrentTextChanged() {
                            if (passwordBox.text !== root.context.currentText)
                                passwordBox.text = root.context.currentText;

                        }

                        target: root.context
                    }

                }

                Rectangle {
                    id: customCaret

                    width: StyleLock.inputCaretWidth
                    height: StyleLock.inputCaretHeight
                    color: StyleLock.inputFontColor
                    visible: root.caretActive
                    opacity: root.caretBlinkOpacity
                    y: (passwordField.height - height) / 2
                    x: passwordField.dotCount === 0 ? (passwordField.width - width) / 2 : passwordDots.x + passwordField.dotsRowWidth + StyleLock.inputDotSpacing / 2

                    Behavior on opacity {
                        NumberAnimation {
                            duration: StyleLock.caretBlinkFadeDuration
                            easing.type: Easing.InOutQuad
                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleLock.glyphFadeDuration
                    }

                }

            }

            HoverHandler {
                onHoveredChanged: root.inputHovered = hovered
            }

        }

    }

    // ── Fade animations ───────────────────────────────────────────────────────
    NumberAnimation {
        id: fadeIn

        target: fadeLayer
        property: "opacity"
        to: 1
        duration: StyleLock.fadeInDuration
        easing.type: Easing.InOutSine
    }

    NumberAnimation {
        id: fadeOut

        target: fadeLayer
        property: "opacity"
        to: 0
        duration: StyleLock.fadeOutDuration
        easing.type: Easing.InOutSine
    }

    Connections {
        function onUnlocked() {
            fadeOut.start();
        }

        target: root.context
    }

}
