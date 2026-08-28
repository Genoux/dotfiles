import QtQuick
import qs.components
import qs.config
import qs.services as Services

Button {
    id: root

    required property var barWindow

    // Bundled marks rather than the icon theme's, so the glyph is tinted with the
    // rest of the bar and matches the volume OSD's own icon.
    iconSource: IconRegistry.volumeIcon(Services.AudioState.sinkVolume, Services.AudioState.sinkMuted, Services.AudioState.hasSink)
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    // Adjusting the level is the one thing worth doing without opening anything.
    WheelHandler {
        onWheel: (event) => {
            const sink = Services.AudioState.sink;
            if (!sink)
                return;

            const delta = event.angleDelta.y > 0 ? StyleControl.sliderStep : -StyleControl.sliderStep;
            Services.AudioState.setVolume(sink, Services.AudioState.sinkVolume + delta);
        }
    }

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        VolumePopover {
            active: popover.open
        }
    }
}
