import QtQuick
import QtQuick.Layouts
import qs
import qs.config

ColumnLayout {
    id: root
    required property var manager
    signal review(var request, string title, string detail)
    spacing: StyleTokens.space12

    ManagerRow {
        Layout.fillWidth: true
        title: !root.manager.updates.checked ? "Ready when you are" : (root.manager.updates.packages || []).length + " updates available"
        description: "Official repositories and AUR · " + root.manager.date(root.manager.updates.checked)
        ManagerButton {
            text: "Check"
            enabled: !root.manager.busy
            onClicked: root.manager.start({action: "check"})
        }
    }
    ManagerLabel {
        Layout.fillWidth: true
        text: "Keep your system and apps current with a full upgrade. Package changes are recorded by your existing dotfiles sync hook."
        color: StyleManager.textColor
    }
    ManagerButton {
        text: "Update everything…"
        enabled: !root.manager.busy
        onClicked: root.review({action: "update"}, "Update system and apps?", "Refresh repositories and upgrade all official and AUR packages. AUR build scripts run as your user. Authentication appears when needed. Package conflicts stop the operation for review.")
    }
    ManagerLabel {
        Layout.fillWidth: true
        visible: (root.manager.updates.errors || []).length > 0
        text: (root.manager.updates.errors || []).join("\n")
        color: StyleManager.textColor
    }
    Repeater {
        model: root.manager.updates.packages || []
        ManagerRow {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.name
            description: modelData.current + "  →  " + modelData.next
            detail: modelData.source === "aur" ? "AUR" : "Official"
        }
    }
}
