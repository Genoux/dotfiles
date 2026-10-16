import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

// The expanded island: one page above a footer menu that reaches every page.
// Pages that already exist as bar popovers are the same components rendered
// `embedded`, so the bar and the island can never drift apart on what a panel
// contains.
Item {
    id: root

    property bool active: false
    property string pageId: "home"

    // The page on screen. It trails `pageId` during a change: the old page has
    // to be gone before the new one is swapped in and the shape resizes.
    property string shownPageId: ""
    property bool switching: false
    property bool arriving: false
    property real pageVeil: 0
    // The shown page's height, copied from it rather than bound to it, and only
    // once it has stopped changing. A page that has just replaced another is
    // briefly built out of its lists, and a binding would send the island to
    // that smaller height before the page arrived at its real one.
    property real pageHeight: 0
    property bool pageUnderFooter: false
    signal pageSelected(string selectedPage)
    signal collapseRequested()
    signal collapseNowRequested()

    // The footer holds the pages used most; the rest are one step further, on
    // the More page.
    readonly property var tabs: ["home", "launcher", "media", "sound", "network", "bluetooth", "capture", "more"]
    readonly property var morePages: ["clipboard", "calendar", "weather", "system", "info", "power"]
    // A page reached from inside another keeps that page's tab lit.
    readonly property var subPages: ({
        "sources": "media"
    })
    readonly property var pages: ({
        "home": homePage,
        "launcher": launcherPage,
        "media": mediaPage,
        "sources": sourcesPage,
        "sound": soundPage,
        "network": networkPage,
        "bluetooth": bluetoothPage,
        "clipboard": clipboardPage,
        "more": morePage,
        "capture": capturePage,
        "calendar": calendarPage,
        "weather": weatherPage,
        "system": systemPage,
        "info": infoPage,
        "power": powerPage
    })
    readonly property string shownTab: morePages.includes(shownPageId) ? "more" : subPages[shownPageId] ?? shownPageId
    readonly property int tabIndex: tabs.indexOf(shownTab)
    readonly property bool pageLive: active && !switching
    readonly property bool wantsKeyboard: {
        switch (shownPageId) {
        case "launcher":
        case "clipboard":
            return true;
        case "network":
            return Services.WifiState.passphrasePath.length > 0;
        case "bluetooth":
            return Services.BluetoothState.pairingNeedsInput;
        default:
            return false;
        }
    }

    function syncPageSize() {
        const page = pageLoader.item;
        if (!page)
            return;

        pageHeight = page.implicitHeight;
        pageUnderFooter = page.underFooter === true;
    }

    function pageSizeChanged() {
        if (switching)
            return;

        if (pageHeight === 0)
            syncPageSize();
        else
            sizeSettle.restart();
    }

    function adoptPage() {
        sizeSettle.stop();
        sizeLimit.stop();
        arriving = false;
        syncPageSize();
        pageIn.restart();
    }

    implicitWidth: shownPageId === "info" ? StyleIsland.wideWidth : StyleIsland.pageWidth
    implicitHeight: pageHeight + (pageUnderFooter ? 0 : footer.height)
    width: implicitWidth

    Component.onCompleted: shownPageId = pageId

    onPageIdChanged: {
        if (shownPageId === "")
            return;

        pageIn.stop();
        arriving = false;
        pageOut.restart();
    }

    // A page change is out, resize, in: one motion rather than two pages
    // overlapping. The old page is deactivated before it goes so its panel runs
    // its own close handlers.
    SequentialAnimation {
        id: pageOut

        // Deactivated, the old page lays out smaller; the island must not
        // follow it down on its way out.
        ScriptAction {
            script: {
                root.switching = true;
                sizeSettle.stop();
            }
        }

        NumberAnimation {
            target: root
            property: "pageVeil"
            to: 1
            duration: StyleIsland.pageOutDuration
            easing.type: StyleIsland.veilEasing
        }

        // The new page goes live at once, still hidden: a panel lays out
        // differently inactive (its lists are not built), and activating it
        // only when it appears would resize the island a second time. The
        // island keeps the old size until the new page has stopped growing, so
        // it moves once, straight to where it is going.
        ScriptAction {
            script: {
                root.shownPageId = root.pageId;
                root.switching = false;
                root.arriving = true;
                sizeSettle.restart();
                sizeLimit.restart();
            }
        }
    }

    SequentialAnimation {
        id: pageIn

        NumberAnimation {
            target: root
            property: "pageVeil"
            to: 0
            duration: StyleIsland.pageInDuration
            easing.type: StyleIsland.veilEasing
        }
    }

    Timer {
        id: sizeSettle

        interval: StyleIsland.pageSizeSettle
        onTriggered: root.arriving ? root.adoptPage() : root.syncPageSize()
    }

    // A page whose content keeps arriving (a scan) would otherwise hold the
    // island at its old size indefinitely.
    Timer {
        id: sizeLimit

        interval: StyleIsland.pageSizeLimit
        onTriggered: {
            if (root.arriving)
                root.adoptPage();
        }
    }

    Veil {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.implicitWidth
        height: root.pageHeight
        veil: root.pageVeil
        keepLaidOut: true

        // A page that runs under the footer dissolves into it rather than being
        // cut off above it: it is gone by the time it reaches the track. The
        // fade is measured from the live bottom edge, not the page's own: while
        // the shape is still growing to the page, rows that sat where the dock
        // is were left unfaded and drew over it. Any other page is cut at the
        // track's top while the shape is shorter than it, measured against its
        // live height: `pageHeight` trails a page that grows in place by the
        // settle delay, long enough for its new rows to draw over the dock.
        Item {
            width: parent.width
            height: parent.height
            layer.enabled: root.pageUnderFooter || root.height < (pageLoader.item ? pageLoader.item.implicitHeight : 0) + StyleIsland.footerHeight
            // OpacityMask multiplies by the mask's alpha. MultiEffect's mask is a
            // threshold map, so a gradient through it clips instead of fading.
            layer.effect: OpacityMask {
                maskSource: fadeMask
            }

            Loader {
                id: pageLoader

                sourceComponent: root.pages[root.shownPageId] ?? null
                onItemChanged: root.pageSizeChanged()
            }
        }

        Item {
            id: fadeMask

            width: parent.width
            height: parent.height
            visible: false
            layer.enabled: true

            Rectangle {
                id: fadeRamp

                readonly property real fadeStart: root.pageUnderFooter ? StyleIsland.footerFadeStart : StyleIsland.footerHeight - StyleIsland.footerInset
                readonly property real fadeEnd: root.pageUnderFooter ? StyleIsland.footerFadeEnd : fadeStart

                function stop(fromBottom) {
                    return Math.min(1, Math.max(0, (root.height - fromBottom) / Math.max(1, height)));
                }

                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#ff000000" }
                    GradientStop { position: fadeRamp.stop(fadeRamp.fadeStart); color: "#ff000000" }
                    GradientStop { position: fadeRamp.stop(fadeRamp.fadeEnd); color: StyleTokens.transparent }
                    GradientStop { position: 1; color: StyleTokens.transparent }
                }
            }
        }

        Connections {
            target: pageLoader.item
            ignoreUnknownSignals: true

            function onImplicitHeightChanged() {
                root.pageSizeChanged();
            }
        }

        Binding {
            target: pageLoader.item
            property: "active"
            value: root.pageLive
            when: pageLoader.item !== null && "active" in pageLoader.item
        }
    }

    Item {
        id: footer

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: StyleIsland.pageWidth
        height: StyleIsland.footerHeight

        Rectangle {
            id: track

            anchors.fill: parent
            anchors.margins: StyleIsland.footerInset
            radius: StyleIsland.footerTrackRadius
            color: StyleTokens.alphaLight

            DockTabs {
                anchors.centerIn: parent
                tabs: root.tabs
                currentTab: root.shownTab
                onTabSelected: (tab) => root.pageSelected(tab)
            }
        }
    }

    Component {
        id: homePage

        HomePage {
            onPageRequested: (requestedPage) => root.pageSelected(requestedPage)
            onCollapseRequested: root.collapseRequested()
        }
    }

    Component {
        id: launcherPage

        LauncherPage {
            onCollapseRequested: root.collapseRequested()
        }
    }

    Component {
        id: mediaPage

        MediaPage {
            onPageRequested: (requestedPage) => root.pageSelected(requestedPage)
        }
    }

    Component {
        id: sourcesPage

        MediaSourcesPage {
            onPageRequested: (requestedPage) => root.pageSelected(requestedPage)
        }
    }

    Component {
        id: soundPage

        Widgets.VolumePopover {
            embedded: true
        }
    }

    Component {
        id: networkPage

        Widgets.NetworkPopover {
            embedded: true
        }
    }

    Component {
        id: bluetoothPage

        Widgets.BluetoothPopover {
            embedded: true
        }
    }

    Component {
        id: clipboardPage

        Widgets.ClipboardPopover {
            embedded: true
            onDismiss: root.collapseRequested()
        }
    }

    Component {
        id: morePage

        MorePage {
            onPageRequested: (requestedPage) => root.pageSelected(requestedPage)
        }
    }

    Component {
        id: capturePage

        Widgets.CapturePopover {
            embedded: true
            onDismissRequested: root.collapseNowRequested()
        }
    }

    Component {
        id: calendarPage

        Widgets.ClockPopover {
            embedded: true
        }
    }

    Component {
        id: weatherPage

        Widgets.WeatherPopover {
            embedded: true
        }
    }

    Component {
        id: systemPage

        Widgets.SystemMonitorPopover {
            embedded: true
            popoverWidth: StyleIsland.pageWidth
            onBtopRequested: {
                root.collapseRequested();
                ShellActions.launchOrFocus("btop", "btop", "htop");
            }
        }
    }

    Component {
        id: infoPage

        Widgets.SystemInfoPopover {
            embedded: true
            popoverWidth: StyleIsland.wideWidth
        }
    }

    Component {
        id: powerPage

        PowerPage {
            onActionChosen: root.collapseRequested()
        }
    }
}
