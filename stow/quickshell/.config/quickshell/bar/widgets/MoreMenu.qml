import QtQuick
import qs
import qs.components
import qs.config
import qs.services as Services

// The three dots: the tools that have no button of their own. A grid of tiles
// opens the one picked as its own popover over this same button, the way each
// has its own widget in the old bar.
Button {
    id: root

    required property var barWindow

    readonly property var entries: [
        { id: "calendar", label: "Calendar", icon: IconRegistry.themeIcon("calendar-symbolic") },
        { id: "weather", label: "Weather", icon: IconRegistry.weatherIcon(Services.WeatherState.icon) },
        { id: "system", label: "System", icon: IconRegistry.themeIcon("utilities-system-monitor-symbolic") },
        { id: "info", label: "About", icon: IconRegistry.barControlIcon("info") },
        { id: "power", label: "Power", icon: IconRegistry.barControlIcon("power") },
        { id: "island", label: "Island", icon: IconRegistry.themeIcon("view-restore-symbolic") }
    ]
    readonly property var panels: ({
        "calendar": calendar,
        "weather": weather,
        "system": system,
        "info": info,
        "power": power
    })

    function choose(entryId) {
        menu.dismissNow();
        if (entryId === "island")
            Services.ShellLayout.setWide(false);
        else
            root.panels[entryId].open = true;
    }

    interactive: true
    iconSource: IconRegistry.themeIcon("view-more-symbolic")
    active: menu.open
    onClicked: menu.toggle()
    Accessible.name: "More"

    BarPopover {
        id: menu

        barWindow: root.barWindow
        anchorItem: root

        PopoverPanel {
            active: menu.open
            fitContent: true

            Item {
                implicitWidth: grid.implicitWidth + StyleIsland.fillInset * 2
                implicitHeight: grid.implicitHeight + StyleIsland.fillInset * 2

                SlidingHighlight {
                    run: grid
                }

                Grid {
                    id: grid

                    x: StyleIsland.fillInset
                    y: StyleIsland.fillInset
                    columns: 3
                    spacing: StyleIsland.tileGridGap

                    Repeater {
                        model: root.entries

                        PopoverTile {
                            required property var modelData

                            width: StylePopover.tileWidth + StyleTokens.space16
                            label: modelData.label
                            iconSource: modelData.icon
                            onActivated: root.choose(modelData.id)
                        }
                    }
                }
            }
        }
    }

    BarPopover {
        id: calendar

        barWindow: root.barWindow
        anchorItem: root

        ClockPopover {
            active: calendar.open
        }
    }

    BarPopover {
        id: weather

        barWindow: root.barWindow
        anchorItem: root

        WeatherPopover {
            active: weather.open
        }
    }

    BarPopover {
        id: system

        barWindow: root.barWindow
        anchorItem: root

        SystemMonitorPopover {
            active: system.open
        }
    }

    BarPopover {
        id: info

        barWindow: root.barWindow
        anchorItem: root
        centered: true

        SystemInfoPopover {
            active: info.open
            onCloseRequested: info.open = false
        }
    }

    BarPopover {
        id: power

        barWindow: root.barWindow
        anchorItem: root

        PopoverMenu {
            active: power.open
            iconRow: true
            entries: Services.PowerMenu.entries
            onSelected: (index) => {
                power.dismissNow();
                Services.PowerMenu.activate(Services.PowerMenu.entries[index]);
            }
        }
    }

    // Super+Escape reaches the shell over IPC, which has no anchor of its own.
    Connections {
        target: Services.PowerMenu

        function onToggleRequested(targetScreen) {
            if (targetScreen === root.barWindow?.screen)
                power.toggle();
        }
    }
}
