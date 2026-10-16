import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

Item {
    id: root

    property bool active: false

    signal pageRequested(string pageId)

    readonly property var entries: [
        { id: "clipboard", label: "Clipboard", icon: IconRegistry.themeIcon("edit-paste-symbolic") },
        { id: "calendar", label: "Calendar", icon: IconRegistry.themeIcon("calendar-symbolic") },
        { id: "weather", label: "Weather", icon: IconRegistry.weatherIcon(Services.WeatherState.icon) },
        { id: "system", label: "System", icon: IconRegistry.themeIcon("utilities-system-monitor-symbolic") },
        { id: "info", label: "About", icon: IconRegistry.barControlIcon("info") },
        { id: "power", label: "Power", icon: IconRegistry.barControlIcon("power") }
    ]
    readonly property int columns: 3
    readonly property int tileWidth: (width - StyleIsland.fillInset * 2 - StyleIsland.tileGridGap * (columns - 1)) / columns

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: content.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Column {
        id: content

        width: parent.width
        spacing: 0

        PopoverHeader {
            width: parent.width
            title: "More"

            Row {
                spacing: StyleTokens.space4

                PillButton {
                    text: Services.ShellLayout.wide ? "Island" : "Wide"
                    Accessible.name: Services.ShellLayout.wide ? "Switch to island" : "Switch to wide bar"
                    onClicked: Services.ShellLayout.toggleWide()
                }
            }
        }

        PopoverSeparator {
            width: parent.width
        }

        Item {
            width: parent.width
            height: grid.implicitHeight + StyleIsland.fillPaddingTop + StyleIsland.pagePaddingBottom

            SlidingHighlight {
                run: grid
            }

            Grid {
                id: grid

                anchors.top: parent.top
                anchors.topMargin: StyleIsland.fillPaddingTop
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.columns
                spacing: StyleIsland.tileGridGap

                Repeater {
                    model: root.entries

                    PopoverTile {
                        required property var modelData

                        width: root.tileWidth
                        label: modelData.label
                        iconSource: modelData.icon
                        onActivated: root.pageRequested(modelData.id)
                    }
                }

                PopoverTile {
                    width: root.tileWidth
                    label: "Nebula"
                    iconSource: IconRegistry.barControlIcon("nebula")
                    active: Services.Nebula.active
                    onActivated: Services.Nebula.toggle()
                }
            }
        }
    }
}
