import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../theme"

Scope {
	id: root

	// Bind the pipewire node so its volume will be tracked
	PwObjectTracker {
		objects: [ Pipewire.defaultAudioSink ]
	}

	Connections {
		target: Pipewire.defaultAudioSink?.audio

		function onVolumeChanged() {
			root.shouldShowOsd = true;
			hideTimer.restart();
		}
	}

	property bool shouldShowOsd: false
	property bool isMuted: Pipewire.defaultAudioSink?.audio?.muted || false
    property real volume: Pipewire.defaultAudioSink?.audio?.volume || 0

				    property string volumeIconName: {
        if (isMuted || volume === 0) {
            return "audio-volume-muted"
        } else if (volume < 0.33) {
            return "audio-volume-low"
        } else if (volume < 0.66) {
            return "audio-volume-medium"
        } else {
            return "audio-volume-high"
        }
    }

	Timer {
		id: hideTimer
		interval: 1200
		onTriggered: root.shouldShowOsd = false
	}

	// The OSD window will be created and destroyed based on shouldShowOsd.
	// PanelWindow.visible could be set instead of using a loader, but using
	// a loader will reduce the memory overhead when the window isn't open.
	LazyLoader {
		active: root.shouldShowOsd

		PanelWindow {
			// Since the panel's screen is unset, it will be picked by the compositor
			// when the window is created. Most compositors pick the current active monitor.

			anchors.bottom: true
			margins.bottom: screen.height / 100
			exclusiveZone: 0

			implicitWidth: 160
			implicitHeight: 36
			color: "transparent"

			// An empty click mask prevents the window from blocking mouse events.
			mask: Region {}

			Rectangle {
				anchors.fill: parent
				radius: Theme.radiusSm
				color: Colors.bgTranslucent
				border.width: Theme.borderWidth
				border.color: Qt.rgba(Colors.accentMuted.r, Colors.accentMuted.g, Colors.accentMuted.b, 0.02)
				
				// Start invisible and fade in
				opacity: 0
				
				// Smooth fade in/out animation
				Behavior on opacity {
					NumberAnimation {
						duration: Theme.transitionNormal
						easing.type: Easing.OutCubic
					}
				}
				
				// Trigger fade in when component is created
				Component.onCompleted: opacity = 1

				RowLayout {
					anchors {
						fill: parent
						rightMargin: Theme.spacingLg
						leftMargin: Theme.spacingMd
						topMargin: 2
					}

					IconImage {
						implicitSize: 18
						source: Quickshell.iconPath(volumeIconName)
					}

					Rectangle {
						// Stretches to fill all left-over space
						Layout.fillWidth: true

						implicitHeight: 6
						radius: 20
						color: Qt.rgba(Colors.accentMuted.r, Colors.accentMuted.g, Colors.accentMuted.b, 0.1)

						Rectangle {
							anchors {
								left: parent.left
								top: parent.top
								bottom: parent.bottom
							}

							implicitWidth: parent.width * (Pipewire.defaultAudioSink?.audio.volume ?? 0)
							radius: parent.radius
						}
					}
				}
			}
		}
	}
}
