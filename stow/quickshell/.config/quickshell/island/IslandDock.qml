import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.bar.widgets as Widgets
import qs.config
import qs.services as Services

// Workspaces and the tray exactly as the bar draws them: same widgets, same
// row, same margins, nothing behind them. The window is as tall as the bar so
// the tray's context menus anchor to the same geometry they do there.
PanelWindow {
    id: root

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property int contentHeight: Math.max(StyleBar.estimatedContentHeight, dockRow.implicitHeight)

    color: StyleBar.background
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: dockRow.implicitWidth + StyleBar.margin * 2
    implicitHeight: contentHeight + StyleBar.topPadding + StyleBar.bottomPadding

    anchors {
        bottom: true
        left: true
    }

    // Always interactive, so it has to stay reachable while an island panel
    // holds Hyprland's exclusive pointer grab. `visible` never changes here, so
    // a visibility handler would never fire.
    Component.onCompleted: Services.PopoverCoordinator.registerGrabPassthrough(root, true)
    Component.onDestruction: Services.PopoverCoordinator.registerGrabPassthrough(root, false)

    RowLayout {
        id: dockRow

        x: StyleBar.margin
        y: StyleBar.topPadding + (root.contentHeight - height) / 2
        spacing: StyleTokens.space6

        Widgets.Workspaces {
            Layout.alignment: Qt.AlignVCenter
            hyprMonitor: root.hyprMonitor
        }

        Widgets.SystemTray {
            Layout.alignment: Qt.AlignVCenter
            barWindow: root
        }
    }
}
