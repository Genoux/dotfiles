import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./widgets"
import "./theme"

ShellRoot {
    
    // Volume OSD overlay
    VolumeOsd {}
    
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            required property var modelData
            screen: modelData
            
            anchors {
                bottom: true
                left: true
                right: true
            }

            margins {
                left: Theme.spacingXs
                right: Theme.spacingXs
                bottom: Theme.spacingXs
            }
            
            implicitHeight: Theme.barHeight
       
            
            color: "transparent"
            // Main container with three sections
            RowLayout {
                anchors.fill: parent
         
                spacing: 0
                
              
                // Left Section
                RowLayout {
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignLeft
                    spacing: 0
                    
                    // Workspaces
                    Workspaces {}
                    
                    // System Tray placeholder
                    Rectangle {
                        Layout.preferredWidth: 60
                        Layout.fillHeight: true
                        Layout.margins: Theme.spacingXs
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Tray"
                            color: Colors.textPrimary
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }
                }
                
                // Center Section
                Item {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200
                        height: parent.height - (Theme.spacingXs * 2)
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Window Title"
                            color: Colors.textPrimary
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }
                }
                
                // Right Section
                RowLayout {
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignRight
                    spacing: 0
                    
                    // Audio Visualizer placeholder
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.fillHeight: true
                        Layout.margins: Theme.spacingXs
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Cava"
                            color: Colors.textSecondary
                            font.pixelSize: Theme.fontSizeXs
                        }
                    }
                    
                    // System Info placeholders
                    Rectangle {
                        Layout.preferredWidth: 60
                        Layout.fillHeight: true
                        Layout.margins: Theme.spacingXs
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Temp"
                            color: Colors.textSecondary
                            font.pixelSize: Theme.fontSizeXs
                        }
                    }
                    
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.fillHeight: true
                        Layout.margins: Theme.spacingXs
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Bat"
                            color: Colors.textSecondary
                            font.pixelSize: Theme.fontSizeXs
                        }
                    }
                    
                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.fillHeight: true
                        Layout.margins: Theme.spacingXs
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Weather"
                            color: Colors.textSecondary
                            font.pixelSize: Theme.fontSizeXs
                        }
                    }
                    
                    // Audio Controls
                    AudioControls {}
                    
                    // Time Display
                    TimeDisplay {}
                    
                    // Control Panel
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.fillHeight: true
                        Layout.margins: Theme.spacingXs
                        color: Colors.bgTranslucent
                        border.width: Theme.borderWidth
                        border.color: Colors.borderTertiary
                        radius: Theme.radiusSm
                        
                        Text {
                            anchors.centerIn: parent
                            text: "⚙"
                            color: Colors.textPrimary
                            font.pixelSize: Theme.fontSizeLg
                        }
                    }
                }
            }
        }
    }
}