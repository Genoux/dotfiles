import QtQuick
import QtQuick.Layouts
import qs
import qs.config

ColumnLayout {
    id: root
    required property var manager
    signal review(var request, string title, string detail)
    property var selected: []
    readonly property var categories: [
        {key: "trash", title: "Trash", description: "Permanently delete files in your home trash."},
        {key: "packages", title: "Package cache", description: "Keep two installed versions for rollback."},
        {key: "aur", title: "AUR build cache", description: "Clear downloaded sources and cached builds."},
        {key: "downloads", title: "Interrupted downloads", description: "Clear leftover pacman download folders."},
        {key: "npm", title: "npm cache", description: "Clear downloaded npm packages."},
        {key: "apps", title: "Application caches", description: "Clear ~/.cache; running apps may recreate files."},
        {key: "journal", title: "System journal", description: "Keep the last two weeks of logs."},
        {key: "orphans", title: "Orphaned packages", description: "Remove only the unused dependencies shown below."}
    ]
    spacing: StyleTokens.space8

    RowLayout {
        Layout.fillWidth: true
        ManagerLabel {
            Layout.fillWidth: true
            text: "Choose what to clear. Sizes show total storage, not a guaranteed reclaim estimate."
            color: StyleManager.textColor
        }
        ManagerButton {
            text: root.selected.length > 0 ? "Clear selection" : "Select all"
            enabled: !root.manager.busy
            onClicked: root.selected = root.selected.length > 0 ? [] : root.categories.filter(item => item.key !== "orphans" || !!root.manager.cleanup.checked).map(item => item.key)
        }
        ManagerButton {
            text: "Scan"
            enabled: !root.manager.busy
            onClicked: root.manager.start({action: "scan"})
        }
    }
    ManagerLabel {
        Layout.fillWidth: true
        visible: (root.manager.cleanup.errors || []).length > 0
        text: (root.manager.cleanup.errors || []).join("\n")
        color: StyleManager.textColor
    }
    Repeater {
        model: root.categories
        ManagerRow {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.title
            description: modelData.description
            detail: modelData.key === "orphans" ? (root.manager.cleanup.orphans || []).length + " packages"
                : ["journal", "downloads"].includes(modelData.key) ? "" : root.manager.size((root.manager.cleanup.sizes || {})[modelData.key])
            ManagerButton {
                text: root.selected.includes(modelData.key) ? "Selected" : "Select"
                active: root.selected.includes(modelData.key)
                enabled: !root.manager.busy && (modelData.key !== "orphans" || !!root.manager.cleanup.checked)
                onClicked: root.selected = root.selected.includes(modelData.key)
                    ? root.selected.filter(key => key !== modelData.key) : root.selected.concat([modelData.key])
            }
        }
    }
    ManagerLabel {
        Layout.fillWidth: true
        visible: root.selected.includes("orphans")
        text: "Unused dependencies: " + ((root.manager.cleanup.orphans || []).join(", ") || "None")
        color: StyleManager.textColor
    }
    function reviewSelection() {
        root.review({action: "cleanup", categories: root.selected.slice(), orphans: (root.manager.cleanup.orphans || []).slice()},
            "Clean selected items?", root.categories.filter(item => root.selected.includes(item.key)).map(item => item.title + ": " + item.description).join("\n")
            + (root.selected.includes("orphans") ? "\nPackages: " + ((root.manager.cleanup.orphans || []).join(", ") || "None") : ""))
    }
}
