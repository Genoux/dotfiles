import QtQuick
import QtQuick.Effects
import qs.config

// Hides its content behind opacity, blur and a slight scale. `veil` is 0 when
// the content is fully shown and 1 when it is gone.
//
// The offscreen layer exists only while the veil is partly down: blurring needs
// the content rendered to a texture, and keeping that texture around for a
// panel that is simply sitting there would cost every frame for nothing.
Item {
    id: root

    property real veil: 0
    property int blurMax: StyleIsland.blurMax
    // A hidden item is not laid out, and a list inside it builds nothing until
    // it is shown. Content whose size has to be known before it appears keeps
    // its `visible`; at full veil it is transparent, so nothing is drawn anyway.
    property bool keepLaidOut: false

    opacity: 1 - veil
    scale: 1 - (1 - StyleIsland.veilScale) * veil
    visible: veil < 1 || keepLaidOut
    layer.enabled: veil > 0 && veil < 1
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: root.blurMax
        blur: root.veil
    }
}
