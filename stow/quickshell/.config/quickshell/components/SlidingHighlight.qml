import QtQuick
import qs.config

// One indicator shared by a row of peers, moved between them instead of being
// faded in and out on each. The movement carries the meaning: a fill that
// appears in place says "this one", a fill that travels says "this one rather
// than the one you were on", which is what a row of siblings actually is.
//
// Give it a `target` and place it before the row in the same parent, so it
// paints behind. It never lays out with the row -- position it, do not anchor.
Rectangle {
    id: highlight

    // The peer to sit behind. Null fades the indicator out where it stands.
    property Item target: null

    // The container whose children are the run of peers. Set this and the
    // indicator finds its own target, following whichever child reports
    // `hovered`. Leave it null to drive `target` yourself, as a control with a
    // selected item rather than a hovered one does.
    property Item run: null

    // A run is not always one flat list: a calendar is a column of week rows,
    // and the peers are the day cells inside them. Anything that reports
    // `hovered` is a peer; anything that does not is a grouping to look inside.
    function peerUnder(container) {
        for (const child of container.children) {
            if (child.hovered !== undefined) {
                if (child.hovered)
                    return child
                continue
            }

            const nested = peerUnder(child)
            if (nested)
                return nested
        }
        return null
    }

    readonly property Item hoveredPeer: run ? peerUnder(run) : null

    // Crossing the seam between two neighbours must not blink the fill off, but
    // coming to rest on something that is not a peer — a panel title, a header,
    // empty space inside the same container — must let it go. A short grace
    // covers the seam; anything slower than that is the pointer leaving, and
    // holding for as long as the pointer is anywhere in the container left the
    // fill sitting on a row nobody was pointing at.
    Timer {
        id: releaseGrace

        interval: StyleTokens.motionHoverGrace
        onTriggered: highlight.target = null
    }

    onHoveredPeerChanged: {
        if (hoveredPeer) {
            releaseGrace.stop()
            target = hoveredPeer
        } else if (target) {
            releaseGrace.restart()
        }
    }

    // The last peer worth drawing. Geometry follows this rather than `target`
    // so a null target dims the indicator in place instead of collapsing it
    // into the corner on its way out.
    property Item shownTarget: null

    // A first appearance must not travel from wherever the last one died.
    property bool travels: false

    radius: StyleTokens.radiusSm
    color: StyleTokens.alphaLight
    visible: opacity > 0
    opacity: target ? 1 : 0

    // Real bindings, so the indicator keeps following a peer that moves or
    // resizes under it -- bar widgets grow on hover through Button's trail
    // reveal, and workspace pills resize with their contents.
    // A peer reports its position inside its own parent, which may be a week row
    // in a grid, or a row centred inside a wrapper. Measure to the ancestor the
    // peer and this indicator share, then back down to the indicator's parent —
    // summing blindly up the chain double-counts any inset the indicator's own
    // parent already carries. Every `.x` and `.parent` read here is a tracked
    // dependency, so this stays a live binding, which is the whole mechanism: no
    // call site should ever assign x or y, which would replace it and freeze the
    // fill in place.
    function offsetOn(peer, axis) {
        const anchors = new Set()
        for (let node = parent; node; node = node.parent)
            anchors.add(node)

        let down = 0
        let shared = null
        for (let node = peer; node; node = node.parent) {
            if (anchors.has(node)) {
                shared = node
                break
            }
            down += node[axis]
        }

        let up = 0
        for (let node = parent; node && node !== shared; node = node.parent)
            up += node[axis]

        return down - up
    }

    x: shownTarget ? offsetOn(shownTarget, "x") : 0
    y: shownTarget ? offsetOn(shownTarget, "y") : 0
    width: shownTarget ? shownTarget.width : 0
    height: shownTarget ? shownTarget.height : 0

    onTargetChanged: {
        if (!target)
            return

        travels = opacity > 0
        shownTarget = target
        travels = true
    }

    Behavior on x {
        enabled: highlight.travels
        NumberAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    Behavior on y {
        enabled: highlight.travels
        NumberAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    Behavior on width {
        enabled: highlight.travels
        NumberAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    Behavior on height {
        enabled: highlight.travels
        NumberAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: StyleTokens.motionFeedbackDuration
            easing.type: StyleTokens.easeFade
        }
    }
}
