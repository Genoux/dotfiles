import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs
import qs.components
import qs.config

FocusScope {
    id: root
    required property var manager
    signal closeRequested()
    property string page: "overview"
    property var pending: null
    property string reviewTitle: ""
    property string reviewDetail: ""
    readonly property var pages: manager.catalog || []
    readonly property var section: pages.find(item => item.id === page) || ({id: page, title: "Workspace Settings", description: "Loading…", actions: []})

    function review(request, title, detail) {
        pending = request
        reviewTitle = title
        reviewDetail = detail
        Qt.callLater(() => cancelButton.forceActiveFocus())
    }

    Keys.onEscapePressed: {
        if (pending)
            pending = null
        else
            closeRequested()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: StyleManager.padding
        spacing: StyleTokens.space20
        enabled: !root.pending && !root.manager.prompt.id

        ColumnLayout {
            Layout.minimumWidth: StyleManager.sidebarWidth
            Layout.maximumWidth: StyleManager.sidebarWidth
            Layout.fillHeight: true
            spacing: StyleTokens.space8
            ManagerLabel {
                text: "Workspace settings"
                font.pixelSize: StyleTokens.fontSizeLg
                font.weight: Font.DemiBold
                Layout.bottomMargin: StyleTokens.space20
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: navigation.implicitHeight
                clip: true
                Controls.ScrollBar.vertical: Controls.ScrollBar {}
                ColumnLayout {
                    id: navigation
                    width: parent.width
                    spacing: StyleTokens.space2
                    Repeater {
                        model: root.pages
                        ManagerButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.title
                            Layout.topMargin: ["configs", "installation", "activity"].includes(modelData.id) ? StyleTokens.space12 : 0
                            minimumHeight: StyleTokens.space8 * 4
                            trailWidth: StyleTokens.space1
                            paddingHorizontal: StyleTokens.space12
                            borderColor: activeFocus ? foreground : StyleTokens.transparent
                            foreground: StyleManager.textColor
                            radius: StyleTokens.radiusXs
                            active: root.page === modelData.id
                            onClicked: root.page = modelData.id
                        }
                    }
                }
            }
            ManagerLabel {
                Layout.fillWidth: true
                text: root.manager.size(root.manager.snapshot.diskFree) + " free"
                color: StyleManager.textColor
                font.pixelSize: StyleTokens.fontSizeXs
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: StyleTokens.borderWidth
            color: StyleOverlay.borderSubtle
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: StyleTokens.space16
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: StyleTokens.space4
                    ManagerLabel {
                        text: root.section.title
                        font.pixelSize: StyleTokens.fontSizeLg
                        font.weight: Font.DemiBold
                    }
                    ManagerLabel {
                        Layout.fillWidth: true
                        text: root.section.description
                        color: StyleManager.textColor
                    }
                }
                ManagerButton {
                    text: "Close"
                    borderColor: activeFocus ? foreground : StyleTokens.transparent
                    onClicked: root.closeRequested()
                }
            }
            ManagerLabel {
                Layout.fillWidth: true
                visible: root.manager.error.length > 0
                text: root.manager.error
                color: StyleManager.textColor
            }
            Flickable {
                id: contentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: pageContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {}

                ColumnLayout {
                    id: pageContent
                    width: contentScroll.width - StyleTokens.space12
                    spacing: StyleTokens.space12
                    OperationPage {
                        Layout.fillWidth: true
                        visible: !["updates", "cleanup", "temporary", "activity"].includes(root.page)
                        manager: root.manager
                        section: root.section
                        onReview: (request, title, detail) => root.review(request, title, detail)
                        onActivityRequested: root.page = "activity"
                    }
                    UpdatesPage {
                        Layout.fillWidth: true
                        visible: root.page === "updates"
                        manager: root.manager
                        onReview: (request, title, detail) => root.review(request, title, detail)
                    }
                    CleanupPage {
                        id: cleanupPage
                        Layout.fillWidth: true
                        visible: root.page === "cleanup"
                        manager: root.manager
                        onReview: (request, title, detail) => root.review(request, title, detail)
                    }
                    TemporaryPage {
                        Layout.fillWidth: true
                        visible: root.page === "temporary"
                        manager: root.manager
                        onReview: (request, title, detail) => root.review(request, title, detail)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "activity"
                        spacing: StyleTokens.space12
                        ManagerRow {
                            Layout.fillWidth: true
                            title: root.manager.busy ? "Operation in progress" : root.manager.job.status || "No operations yet"
                            description: root.manager.job.action ? root.manager.job.action + " · " + root.manager.date(root.manager.job.started) : "Start with an update check or cleanup scan."
                        }
                        ManagerLabel {
                            Layout.fillWidth: true
                            visible: !!root.manager.job.error
                            text: root.manager.job.error || ""
                            color: StyleManager.textColor
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            ManagerButton { text: "Older output"; enabled: (root.manager.logOffset < 0 ? (root.manager.snapshot.logSize || 0) > 24000 : root.manager.logOffset > 0); onClicked: root.manager.olderOutput() }
                            ManagerButton { text: "Newer output"; enabled: root.manager.logOffset >= 0; onClicked: root.manager.newerOutput() }
                            Item { Layout.fillWidth: true }
                            ManagerButton { text: "Latest"; active: root.manager.logOffset < 0; onClicked: root.manager.logOffset = -1 }
                        }
                        Controls.TextArea {
                            Layout.fillWidth: true
                            readOnly: true
                            selectByMouse: true
                            text: root.manager.activity
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            color: StyleManager.textColor
                            selectionColor: Colors.base03
                            font.family: StyleTokens.fontMono
                            font.pixelSize: StyleTokens.fontSizeSm
                            padding: StyleTokens.space12
                            background: Rectangle {
                                color: StyleTokens.alphaLight
                                radius: StyleTokens.radiusSm
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: StyleTokens.space8
                Controls.BusyIndicator {
                    visible: root.manager.busy
                    running: visible
                    Layout.preferredWidth: StyleTokens.space20
                    Layout.preferredHeight: StyleTokens.space20
                }
                ManagerLabel {
                    Layout.fillWidth: true
                    text: root.manager.prompt.id ? "Waiting for your choice" : root.manager.busy ? "Working · you can close this window" : root.manager.job.status === "failed" || root.manager.job.status === "interrupted" ? "Needs attention · review Activity" : root.manager.job.status === "completed" ? "Last operation completed" : "Ready"
                    color: StyleManager.textColor
                }
                ManagerButton {
                    visible: root.page === "cleanup"
                    text: "Clean selected (" + cleanupPage.selected.length + ")…"
                    enabled: !root.manager.busy && cleanupPage.selected.length > 0
                    onClicked: cleanupPage.reviewSelection()
                }
                ManagerButton {
                    visible: root.page !== "activity" && root.page !== "cleanup" && !!root.manager.job.action
                    text: "Details"
                    onClicked: root.page = "activity"
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !!root.pending
        radius: StyleTokens.radiusMd
        color: StyleOverlay.surface
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(StyleManager.dialogWidth, parent.width - StyleManager.padding * 2)
            height: confirmation.implicitHeight + StyleManager.padding * 2
            radius: StyleTokens.radiusMd
            color: Colors.base00
            border.width: StyleTokens.borderWidth
            border.color: StyleOverlay.borderSubtle
            ColumnLayout {
                id: confirmation
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: StyleManager.padding
                spacing: StyleTokens.space16
                ManagerLabel {
                    id: confirmationTitle
                    Layout.fillWidth: true
                    text: root.reviewTitle
                    font.pixelSize: StyleTokens.fontSizeLg
                    font.weight: Font.DemiBold
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(reviewText.implicitHeight, Math.max(0, root.height - StyleManager.padding * 6 - confirmationTitle.implicitHeight - confirmationButtons.implicitHeight))
                    contentHeight: reviewText.implicitHeight
                    clip: true
                    Controls.ScrollBar.vertical: Controls.ScrollBar {}
                    ManagerLabel {
                        id: reviewText
                        width: parent.width
                        text: root.reviewDetail
                    }
                }
                RowLayout {
                    id: confirmationButtons
                    Layout.alignment: Qt.AlignRight
                    spacing: StyleTokens.space8
                    ManagerButton {
                        id: cancelButton
                        text: "Cancel"
                        onClicked: root.pending = null
                    }
                    ManagerButton {
                        text: "Continue"
                        enabled: !root.manager.busy
                        onClicked: {
                            const request = root.pending
                            root.pending = null
                            root.page = "activity"
                            if (request.action === "restart") {
                                root.closeRequested()
                                ShellActions.run(["systemctl", "reboot"])
                            } else {
                                root.manager.start(request)
                            }
                        }
                    }
                }
            }
        }
    }
    OperationPrompt {
        anchors.fill: parent
        manager: root.manager
    }
    onPendingChanged: if (!pending) forceActiveFocus()
    onPageChanged: contentScroll.contentY = 0
}
