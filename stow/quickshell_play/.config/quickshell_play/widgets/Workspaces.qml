import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

Rectangle {
    id: workspacesContainer
    
    // Container styling to match other components
    color: Colors.bgTranslucent
    border.width: Theme.borderWidth
    border.color: Colors.borderTertiary
    radius: Theme.radiusSm
    
    Layout.preferredHeight: Theme.barHeight - (Theme.spacingXs * 2)
    Layout.fillHeight: false
    
    implicitWidth: workspaces.implicitWidth + (Theme.spacingSm * 2)
    implicitHeight: Theme.barHeight - (Theme.spacingXs * 2)
    
    
    Component.onCompleted: {
        console.log("Workspaces component loaded")
        console.log("Valid workspaces:", validWorkspaces.length)
    }

    function filterValidWorkspaces() {
        var valid = []
        var allWorkspaces = Hyprland.workspaces.values || []
        
        // Always show workspaces 1-10, even if they don't exist yet
        for (var i = 1; i <= 10; i++) {
            var found = false
            for (var j = 0; j < allWorkspaces.length; j++) {
                if (allWorkspaces[j].id === i) {
                    valid.push(allWorkspaces[j])
                    found = true
                    break
                }
            }
            // If workspace doesn't exist yet, create a placeholder
            if (!found) {
                valid.push({id: i, placeholder: true})
            }
        }
        return valid
    }

    property var validWorkspaces: filterValidWorkspaces()
    
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            workspacesContainer.validWorkspaces = workspacesContainer.filterValidWorkspaces()
        }
    }
    
    Row {
        id: workspaces
        anchors.centerIn: parent
        spacing: Theme.spacingXs
        
        Repeater {
            model: workspacesContainer.validWorkspaces
            
            Rectangle {
                required property var modelData
                
                property bool isActive: Hyprland.focusedWorkspace ? modelData.id === Hyprland.focusedWorkspace.id : false
                property bool isPlaceholder: modelData.placeholder === true
                property bool hasWindows: {
                    if (isPlaceholder) return false  // Placeholder workspaces have no windows
                    if (!Hyprland.toplevels || !Hyprland.toplevels.values) return false
                    var toplevels = Hyprland.toplevels.values
                    for (var i = 0; i < toplevels.length; i++) {
                        if (toplevels[i].workspace && toplevels[i].workspace.id === modelData.id) {
                            return true
                        }
                    }
                    return false
                }
                
                Component.onCompleted: {
                    console.log("Workspace", modelData.id, "- Active:", isActive, "HasWindows:", hasWindows)
                }
                
                // Update when toplevels change
                Connections {
                    target: Hyprland.toplevels
                    function onValuesChanged() {
                        // Force hasWindows to recalculate
                        parent.hasWindows = Qt.binding(function() {
                            if (!Hyprland.toplevels || !Hyprland.toplevels.values) return false
                            var toplevels = Hyprland.toplevels.values
                            for (var i = 0; i < toplevels.length; i++) {
                                if (toplevels[i].workspace && toplevels[i].workspace.id === parent.modelData.id) {
                                    return true
                                }
                            }
                            return false
                        })
                    }
                }
                
                width: 20
                height: 18
                color: mouseArea.containsMouse && !isActive ? Qt.rgba(Colors.accentMuted.r, Colors.accentMuted.g, Colors.accentMuted.b, 0.1) : "transparent"
                border.width: 0
                radius: Theme.radiusXs
                visible: !isPlaceholder  // Hide placeholder workspaces
                    
                // Dot/pill indicator
                Rectangle {
                    anchors.centerIn: parent
                    width: isActive ? 12 : 6
                    height: 6
                    radius: height / 2
                    color: {
                        if (isActive) return Colors.textPrimary
                        if (hasWindows) return Colors.textSecondary
                        return Colors.textTertiary
                    }
                    visible: hasWindows || (!isActive && !hasWindows && !isPlaceholder)  // Show dot for windows OR inactive empty workspaces
                    
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.transitionNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    // Disabled color animation to prevent glitching
                    // Behavior on color {
                    //     ColorAnimation {
                    //         duration: Theme.transitionNormal
                    //         easing.type: Easing.OutCubic
                    //     }
                    // }
                }
                
                // Always reserve space for number, but make it transparent when not needed
                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: (isActive && !hasWindows && !isPlaceholder) ? Colors.textPrimary : "transparent"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    // Always visible to reserve space, but transparent when not active/empty
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Hyprland.dispatch("workspace " + parent.modelData.id)
                    }
                }
            }
        }
    }
}