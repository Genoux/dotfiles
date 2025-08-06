import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Quickshell.Io
import "../theme"

Rectangle {
    id: muteButton
    Layout.preferredWidth: 32
    Layout.fillHeight: true
    Layout.margins: Theme.spacingXs
    radius: Theme.radiusSm
    
    // Use PwObjectTracker to properly bind the audio sink as required by documentation
    PwObjectTracker {
        id: tracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    
    property var boundSink: Pipewire.defaultAudioSink
    property bool isMuted: boundSink?.audio?.muted || false
    property real volume: boundSink?.audio?.volume || 0
    
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
    
    color: {
        if (boundSink?.audio?.muted !== undefined) {
            return boundSink.audio.muted ? Colors.error : Colors.bgTranslucent
        }
        return Colors.bgSecondary // Secondary bg when not bound
    }
    
    border.width: Theme.borderWidth
    border.color: Colors.borderTertiary
    
    IconImage {
        anchors.centerIn: parent
        width: Theme.fontSizeLg
        height: Theme.fontSizeLg
        source: Quickshell.iconPath(volumeIconName)
        opacity: 0.9
        
        Behavior on opacity {
            NumberAnimation { duration: Theme.transitionFast }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            if (boundSink?.audio?.muted !== undefined) {
                boundSink.audio.muted = !boundSink.audio.muted
            }
        }
        
        onEntered: {
            parent.color = Qt.lighter(parent.color, 1.1)
            parent.children[2].opacity = 1.0 // IconImage opacity
        }
        
        onExited: {
            parent.color = Qt.binding(function() {
                if (boundSink?.audio?.muted !== undefined) {
                    return boundSink.audio.muted ? Colors.error : Colors.bgTranslucent
                }
                return Colors.bgSecondary
            })
            parent.children[2].opacity = 0.9
        }
    }
    
    // Smooth transitions matching AGS theme
    Behavior on color {
        ColorAnimation { duration: Theme.transitionFast }
    }
    
    Behavior on border.color {
        ColorAnimation { duration: Theme.transitionFast }
    }
}
