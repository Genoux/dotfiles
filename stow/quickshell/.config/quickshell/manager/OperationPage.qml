import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs
import qs.config

ColumnLayout {
    id: root
    required property var manager
    required property var section
    signal review(var request, string title, string detail)
    signal activityRequested()
    property bool skipPackages: false
    property bool skipConfigs: false
    property bool freshInstall: false
    property string detailId: ""
    property string detailSection: ""
    spacing: StyleTokens.space12

    ManagerRow {
        Layout.fillWidth: true
        visible: root.section.id === "overview"
        title: root.manager.overview.host || "Reading system information…"
        description: (root.manager.overview.cpu || "") + "\n" + root.manager.size(root.manager.overview.memory) + " memory · " + (root.manager.overview.kernel || "")
        ManagerButton { text: "Refresh"; enabled: !root.manager.busy; onClicked: root.manager.refreshOverview() }
    }
    ManagerRow {
        Layout.fillWidth: true
        visible: root.section.id === "overview"
        title: (root.manager.overview.installedCount || 0) + " installed packages · " + (root.manager.overview.configCount || 0) + " configuration packages"
        description: "Dotfiles " + (root.manager.overview.version || "") + " · " + (root.manager.overview.theme || "GTK theme unavailable")
    }
    ManagerRow {
        Layout.fillWidth: true
        visible: root.section.id === "themes"
        title: root.manager.overview.theme || "Current GTK theme"
        description: "Cursor: " + (root.manager.overview.cursor || "Unknown") + " · Colors follow matugen and the wallpaper."
    }
    ManagerRow {
        Layout.fillWidth: true
        visible: !!root.manager.snapshot.rebootRequired && ["overview", "hardware", "system", "installation"].includes(root.section.id)
        title: "Restart required"
        description: "Restart to finish applying system changes."
        ManagerButton {
            text: "Restart…"
            enabled: !root.manager.busy
            onClicked: root.review({action: "restart"}, "Restart this computer?", "Save your work first. This closes your applications and restarts the computer.")
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.section.id === "installation"
        spacing: StyleTokens.space8
        ManagerLabel { Layout.fillWidth: true; text: "Installation options"; color: StyleManager.textColor; font.pixelSize: StyleTokens.fontSizeXs }
        RowLayout {
            ManagerButton { text: "Skip packages"; active: root.skipPackages; onClicked: root.skipPackages = !root.skipPackages }
            ManagerButton { text: "Skip configurations"; active: root.skipConfigs; onClicked: root.skipConfigs = !root.skipConfigs }
            ManagerButton { text: "Fresh start"; active: root.freshInstall; onClicked: root.freshInstall = !root.freshInstall }
        }
        ManagerLabel {
            Layout.fillWidth: true
            text: "Fresh start clears the install checkpoint. Resume uses the saved checkpoint. Completed steps and backups are managed by the existing installer."
            color: StyleManager.textColor
        }
    }
    Repeater {
        model: root.section.actions || []
        ManagerRow {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.title
            description: modelData.description
            ManagerButton {
                text: modelData.button + (modelData.readOnly ? "" : "…")
                enabled: !root.manager.busy && !(modelData.id === "resume_install" && root.freshInstall)
                onClicked: {
                    const request = {action: "operation", operation: modelData.id, skipPackages: root.skipPackages, skipConfigs: root.skipConfigs, fresh: root.freshInstall}
                    if (modelData.readOnly) {
                        root.detailId = modelData.id
                        root.manager.start(request)
                    } else {
                        root.review(request, modelData.title + "?", modelData.description
                            + (["full_install", "resume_install"].includes(modelData.id) ? "\n\nPackages: " + (root.skipPackages ? "skip" : "include") + "\nConfigurations: " + (root.skipConfigs ? "skip" : "include") + "\nCheckpoint: " + (root.freshInstall ? "start fresh" : "preserve / resume") : "")
                            + "\n\nFollow-up choices appear in this window. Authentication is requested by the system when needed.")
                    }
                }
            }
        }
    }
    ManagerLabel {
        visible: root.manager.busy && root.manager.job.action === root.detailId
        text: "Reading details…"
        color: StyleManager.textColor
    }
    Controls.TextArea {
        Layout.fillWidth: true
        visible: !!root.manager.details[root.detailId]
        readOnly: true
        selectByMouse: true
        text: String(root.manager.details[root.detailId]?.text || "").replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "")
        wrapMode: TextEdit.Wrap
        color: StyleManager.textColor
        font.family: StyleTokens.fontMono
        font.pixelSize: StyleTokens.fontSizeSm
        padding: StyleTokens.space12
        background: Rectangle { color: StyleTokens.alphaLight; radius: StyleTokens.radiusSm }
    }
    PackageInventory {
        Layout.fillWidth: true
        visible: root.section.id === "packages"
        manager: root.manager
    }
    onSectionChanged: {
        if (detailSection === section.id)
            return
        detailSection = section.id
        detailId = (section.actions || []).find(action => action.readOnly)?.id || ""
    }
}
