import Quickshell.Services.Mpris
import Quickshell.Hyprland
import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.config
import qs.components

BarGroup {
    id: root

    property string explicitPlayerKey: ""
    property var recentPlayingKeys: []

    readonly property int recentPlayingMax: 12
    readonly property var activePlayers: Mpris.players.values.filter((candidate) => candidate.playbackState !== MprisPlaybackState.Stopped)
    readonly property var player: pickActivePlayer()
    readonly property string trackText: player ? `${player.trackTitle || player.identity || "Media"}${player.trackArtist ? " - " + player.trackArtist : ""}` : ""
    readonly property bool canGoPrevious: player?.canGoPrevious ?? false
    readonly property bool canGoNext: player?.canGoNext ?? false
    readonly property bool canTogglePlayback: player ? (player.isPlaying ? player.canPause : player.canPlay) : false
    property real scrollOffset: 0

    readonly property bool controlsExpanded: hoverHandler.hovered

    visible: player !== null && trackText.length > 0

    Behavior on color {
        ColorAnimation {
            duration: StyleMedia.controlsRevealDuration
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    Instantiator {
        model: Mpris.players.values

        delegate: Connections {
            required property var modelData

            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.notePlayerPlaying(modelData)
            }

            function onPlaybackStateChanged() {
                if (modelData.isPlaying)
                    root.notePlayerPlaying(modelData)
            }
        }
    }

    Component.onCompleted: {
        for (let i = 0; i < Mpris.players.values.length; i++) {
            const candidate = Mpris.players.values[i]
            if (candidate?.isPlaying)
                notePlayerPlaying(candidate)
        }
    }

    Row {
        id: contentRow

        height: StyleMedia.trackHeight
        spacing: root.controlsExpanded ? 3 : 0

        Rectangle {
            id: mediaInfo

            readonly property real textLeftInset: StyleMedia.textLeftInset
            readonly property real textRightInset: StyleMedia.textRightInset
            readonly property real textViewportLeftMargin: textLeftInset + 2
            readonly property real textViewportRightMargin: 6
            readonly property string scrollText: `${root.trackText} • `
            readonly property real singleTextWidth: mediaMeasure.advanceWidth
            readonly property real textViewportMaxWidth: StyleMedia.infoWidth - textLeftInset - textRightInset
            readonly property bool shouldScroll: singleTextWidth > textViewportMaxWidth
            readonly property real fittedWidth: textLeftInset + singleTextWidth + textRightInset

            width: shouldScroll ? StyleMedia.infoWidth : fittedWidth
            implicitWidth: width
            height: contentRow.height
            radius: StyleTokens.radiusSm
            color: root.controlsExpanded ? StyleTokens.alphaLight : StyleTokens.transparent

            Behavior on color {
                ColorAnimation {
                    duration: StyleMedia.controlsRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: StyleMedia.controlsRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            CavaVisualizer {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.visible
                active: root.player?.isPlaying ?? false
            }

            Item {
                id: textViewport

                anchors.left: parent.left
                anchors.leftMargin: mediaInfo.textViewportLeftMargin
                anchors.right: parent.right
                anchors.rightMargin: mediaInfo.textViewportRightMargin
                anchors.verticalCenter: parent.verticalCenter
                height: mediaLabel.implicitHeight

                readonly property real edgeFade: Math.min(
                    StyleMedia.textFadeWidth / Math.max(width, 1),
                    0.2
                )

                Item {
                    id: textLayer

                    anchors.fill: parent
                    clip: true
                    layer.enabled: mediaInfo.shouldScroll
                    layer.smooth: true
                    layer.effect: OpacityMask {
                        maskSource: textFadeMask
                    }

                    Text {
                        id: mediaLabel

                        x: mediaInfo.shouldScroll ? -root.scrollOffset : 0
                        text: mediaInfo.shouldScroll ? mediaInfo.scrollText + mediaInfo.scrollText : root.trackText
                        color: Colors.base05
                        font.family: StyleTokens.fontMono
                        font.pixelSize: StyleTokens.fontSizeMedia
                    }
                }

                Rectangle {
                    id: textFadeMask

                    anchors.fill: parent
                    visible: false
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: textViewport.edgeFade; color: "#ffffffff" }
                        GradientStop { position: 1 - textViewport.edgeFade; color: "#ffffffff" }
                        GradientStop { position: 1; color: "#00000000" }
                    }
                }
            }

            TextMetrics {
                id: mediaMeasure

                text: root.trackText
                font.family: StyleTokens.fontMono
                font.pixelSize: StyleTokens.fontSizeMedia
            }

            MouseArea {
                id: mediaMouse

                anchors.fill: parent
                acceptedButtons: root.player ? Qt.LeftButton : Qt.NoButton
                cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                onClicked: root.focusPlayerWindow()
            }

            Timer {
                interval: 17
                running: mediaInfo.shouldScroll && root.visible
                repeat: true
                onTriggered: {
                    const loopWidth = mediaLabel.implicitWidth / 2;
                    root.scrollOffset = root.scrollOffset >= loopWidth ? 0 : root.scrollOffset + 0.35;
                }
            }

            onScrollTextChanged: root.scrollOffset = 0
            onShouldScrollChanged: root.scrollOffset = 0
        }

        Item {
            id: controlsReveal

            height: StyleMedia.trackHeight
            width: root.controlsExpanded ? controlsRow.implicitWidth : 0
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: StyleMedia.controlsRevealDuration
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                id: controlsRow

                height: StyleMedia.trackHeight
                spacing: 0
                opacity: root.controlsExpanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleMedia.controlsRevealDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Button {
                    iconName: "media-skip-backward-symbolic"
                    iconSize: StyleControl.iconSizeSm
                    interactive: root.controlsExpanded && root.canGoPrevious
                    onClicked: root.previous()
                }

                Button {
                    iconName: player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    iconSize: StyleControl.iconSizeSm
                    interactive: root.controlsExpanded && root.canTogglePlayback
                    onClicked: root.togglePlayback()
                }

                Button {
                    iconName: "media-skip-forward-symbolic"
                    iconSize: StyleControl.iconSizeSm
                    interactive: root.controlsExpanded && root.canGoNext
                    onClicked: root.next()
                }
            }
        }
    }

    onTrackTextChanged: scrollOffset = 0

    function keysMatch(storedKey, candidate) {
        if (!storedKey || !candidate)
            return false

        const id = playerKey(candidate)
        if (storedKey === id)
            return true

        const left = storedKey.toLowerCase()
        const right = id.toLowerCase()
        return left.includes(right) || right.includes(left)
    }

    function pushRecentPlaying(candidate) {
        const key = playerKey(candidate)
        if (!key)
            return

        const rest = recentPlayingKeys.filter((storedKey) => !keysMatch(storedKey, candidate))
        recentPlayingKeys = [key].concat(rest).slice(0, recentPlayingMax)
    }

    function stackRank(candidate) {
        for (let i = 0; i < recentPlayingKeys.length; i++) {
            if (keysMatch(recentPlayingKeys[i], candidate))
                return i
        }

        return recentPlayingMax + 1
    }

    function pickByStackOrder(candidates) {
        if (!candidates.length)
            return null

        return [...candidates].sort((left, right) => stackRank(left) - stackRank(right))[0]
    }

    function prunePlayerState() {
        const active = activePlayers
        const pruned = recentPlayingKeys.filter((storedKey) => active.some((candidate) => keysMatch(storedKey, candidate)))

        if (pruned.length !== recentPlayingKeys.length)
            recentPlayingKeys = pruned

        if (explicitPlayerKey.length > 0 && !active.some((candidate) => keysMatch(explicitPlayerKey, candidate)))
            explicitPlayerKey = ""
    }

    function pickActivePlayer() {
        prunePlayerState()

        const active = activePlayers
        if (!active.length)
            return Mpris.players.values[0] ?? null

        const playing = active.filter((candidate) => candidate.isPlaying)
        if (playing.length > 0) {
            if (explicitPlayerKey.length > 0) {
                const explicitHit = playing.find((candidate) => keysMatch(explicitPlayerKey, candidate))
                if (explicitHit)
                    return explicitHit
            }

            return pickByStackOrder(playing)
        }

        if (explicitPlayerKey.length > 0) {
            const explicitHit = active.find((candidate) => keysMatch(explicitPlayerKey, candidate))
            if (explicitHit)
                return explicitHit
        }

        return pickByStackOrder(active)
    }

    function notePlayerPlaying(candidate) {
        if (!candidate?.isPlaying)
            return

        pushRecentPlaying(candidate)
    }

    function playerKey(candidate) {
        if (!candidate)
            return ""

        if (candidate.dbusName)
            return candidate.dbusName

        return candidate.desktopEntry || candidate.identity || ""
    }

    function playerMatchTokens(player) {
        const desktopEntry = String(player.desktopEntry || "").replace(/\.desktop$/i, "").toLowerCase()
        const identity = String(player.identity || "").toLowerCase()
        return [...new Set([desktopEntry, identity, ...desktopEntry.split(/[._-]+/), ...identity.split(/[._-]+/)])].filter((token) => token.length > 2)
    }

    function focusToplevel(toplevel) {
        if (!toplevel)
            return false

        if (toplevel.wayland) {
            toplevel.wayland.activate()
            return true
        }

        const address = toplevel.lastIpcObject?.address
        if (address) {
            ShellActions.focusWindow(`address:${address}`)
            return true
        }

        return false
    }

    function focusPlayerHyprlandWindow(player) {
        const tokens = playerMatchTokens(player)
        if (tokens.length > 0) {
            const classMatch = Hyprland.toplevels.values.find((toplevel) => {
                const cls = String(toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "").toLowerCase()
                const initialClass = String(toplevel.lastIpcObject?.initialClass || "").toLowerCase()
                return tokens.some((token) => cls.includes(token) || initialClass.includes(token) || token.includes(cls))
            })

            if (focusToplevel(classMatch))
                return true
        }

        const trackTitle = String(player.trackTitle || "").trim()
        if (trackTitle.length < 3)
            return false

        const normalizedTitle = trackTitle.toLowerCase()
        const titleMatch = Hyprland.toplevels.values.find((toplevel) => String(toplevel.title || "").toLowerCase().includes(normalizedTitle))
        return focusToplevel(titleMatch)
    }

    function markPlayerInteracted() {
        if (!root.player)
            return

        pushRecentPlaying(root.player)
        explicitPlayerKey = playerKey(root.player)
    }

    function focusPlayerWindow() {
        if (!root.player)
            return

        markPlayerInteracted()

        if (root.player.canRaise)
            root.player.raise()

        focusPlayerHyprlandWindow(root.player)
    }

    function raisePlayer() {
        focusPlayerWindow()
    }

    function previous() {
        markPlayerInteracted()
        if (root.player?.canGoPrevious)
            root.player.previous()
    }

    function togglePlayback() {
        if (!root.player)
            return

        markPlayerInteracted()
        if (root.player.isPlaying) {
            if (root.player.canPause)
                root.player.pause()
        } else if (root.player.canPlay) {
            root.player.play()
        }
    }

    function next() {
        markPlayerInteracted()
        if (root.player?.canGoNext)
            root.player.next()
    }
}
