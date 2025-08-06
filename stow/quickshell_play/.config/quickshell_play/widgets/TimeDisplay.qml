import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

Rectangle {
    id: timeDisplay
    
    Layout.preferredWidth: 120
    Layout.fillHeight: true
    Layout.margins: Theme.spacingXs
    radius: Theme.radiusSm
    color: Colors.bgTranslucent
    border.width: Theme.borderWidth
    border.color: Colors.borderTertiary
    
    property string timeFormat: "hh:mm"
    property string dateFormat: "yyyy-MM-dd"
    property bool showDate: false
    
    SystemClock {
        id: clock
        enabled: true
        precision: SystemClock.Seconds
    }
    
    Text {
        anchors.centerIn: parent
        text: {
            try {
                var currentTime = clock.time
                if (currentTime && currentTime.getTime) {
                    return showDate ? 
                        Qt.formatDateTime(currentTime, timeFormat + " " + dateFormat) :
                        Qt.formatDateTime(currentTime, timeFormat)
                }
            } catch (e) {
                console.log("Time formatting error:", e)
            }
            return new Date().toLocaleTimeString(Qt.locale(), "hh:mm")
        }
        color: Colors.textPrimary
        font.pixelSize: Theme.fontSizeSm
        font.bold: true
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            showDate = !showDate
        }
        cursorShape: Qt.PointingHandCursor
        
        onEntered: {
            parent.color = Qt.lighter(parent.color, 1.1)
            parent.border.color = Colors.borderSecondary
        }
        
        onExited: {
            parent.color = Colors.bgTranslucent
            parent.border.color = Colors.borderTertiary
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