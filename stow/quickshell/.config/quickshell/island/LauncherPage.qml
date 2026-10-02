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
        // The island already leaves pageInsetTop above a page, which the top
        // padding takes back, so the field sits the launcher's own inset down.
        topPadding: StyleLauncher.padding - StyleIsland.pageInsetTop
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
