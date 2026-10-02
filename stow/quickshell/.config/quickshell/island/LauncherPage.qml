import QtQuick
import qs.config
import qs.launcher
import qs.services as Services

Item {
    id: root

    property bool active: false

    signal collapseRequested()

    readonly property string normalizedQuery: Services.Launcher.query.toLowerCase().trim()
    readonly property var filteredEntries: Services.LauncherHistory.search(normalizedQuery, StyleLauncher.maxResults)

    // The results run on beneath the dock like every other list, fading into it.
    readonly property bool underFooter: true

    implicitWidth: StyleIsland.pageWidth
    implicitHeight: panel.topPadding + StyleLauncher.searchHeight + panel.spacing + panel.listHeight
    width: implicitWidth
    height: implicitHeight

    onActiveChanged: {
        if (!active)
            return;

        Services.Launcher.query = "";
        panel.resetScroll();
        Qt.callLater(panel.focusSearch);
    }

    Component.onDestruction: Services.Launcher.recordPendingLaunch()

    LauncherPanel {
        id: panel

        anchors.fill: parent
        // The launcher fills the island the way the dock does, so it keeps the
        // dock's own inset from every edge. The island already leaves
        // pageInsetTop above a page, which the top padding takes back.
        padding: StyleIsland.fillInset
        spacing: StyleIsland.fillInset
        // Concentric with the island: its radius less the gap to its edge.
        fieldRadius: StyleIsland.expandedRadius - StyleIsland.fillInset
        topPadding: StyleIsland.fillInset - StyleIsland.pageInsetTop
        bottomPadding: StyleIsland.footerFadeEnd + StyleIsland.footerFadeLength
        listMaxHeight: StyleLauncher.listMaxHeight + StyleIsland.footerHeight
        filteredEntries: root.filteredEntries
        active: root.active
        onLaunch: (entry) => {
            Services.Launcher.launch(entry);
            root.collapseRequested();
        }
        onClose: root.collapseRequested()
    }
}
