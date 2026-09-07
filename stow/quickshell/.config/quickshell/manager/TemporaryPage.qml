import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs
import qs.components
import qs.config

ColumnLayout {
    id: root
    required property var manager
    signal review(var request, string title, string detail)
    property int sourceIndex: 0
    spacing: StyleTokens.space12

    ManagerLabel {
        Layout.fillWidth: true
        text: "Try a package, then keep it or remove it when you’re done. Temporary packages stay out of your permanent package lists. They do not expire automatically."
        color: StyleManager.textColor
    }
    SegmentedControl {
        selectedTextColor: StyleManager.textColor
        textColor: StyleManager.textColor
        Layout.fillWidth: true
        labels: ["Official repository", "AUR"]
        activeFocusOnTab: true
        Keys.onLeftPressed: root.sourceIndex = 0
        Keys.onRightPressed: root.sourceIndex = 1
        Accessible.name: "Package source; left for official, right for AUR"
        currentIndex: root.sourceIndex
        onSegmentSelected: index => root.sourceIndex = index
    }
    Controls.TextField {
        id: packageInput
        Layout.fillWidth: true
        Layout.preferredHeight: StyleManager.inputHeight
        placeholderText: "Exact package name"
        color: StyleManager.textColor
        placeholderTextColor: StyleManager.textColor
        selectionColor: Colors.base03
        selectedTextColor: StyleManager.textColor
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        leftPadding: StyleTokens.space12
        background: Rectangle {
            radius: StyleTokens.radiusSm
            color: StyleTokens.alphaLight
            border.width: StyleTokens.borderWidth
            border.color: packageInput.activeFocus ? StyleManager.textColor : StyleOverlay.borderSubtle
        }
        Accessible.name: "Exact package name"
    }
    ManagerButton {
        text: "Install temporarily…"
        enabled: !root.manager.busy && /^[a-zA-Z0-9@_+][a-zA-Z0-9@._+\-]*$/.test(packageInput.text.trim())
        onClicked: root.review({action: "install", package: packageInput.text.trim(), source: root.sourceIndex === 0 ? "official" : "aur"},
            "Try " + packageInput.text.trim() + "?",
            "Install this package and its dependencies with a full system upgrade to avoid a partial upgrade. "
            + (root.sourceIndex === 1 ? "AUR build scripts run as your user. " : "")
            + "You can remove the package here later, or choose Keep to add it to dotfiles.")
    }
    ManagerLabel {
        text: "Temporary packages"
        font.pixelSize: StyleTokens.fontSizeXs
        color: StyleManager.textColor
        Layout.topMargin: StyleTokens.space12
    }
    ManagerRow {
        Layout.fillWidth: true
        visible: root.manager.temporary.length === 0
        title: "No temporary packages"
        description: "Packages you try here will appear in this list."
    }
    Repeater {
        model: root.manager.temporary
        ManagerRow {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.name
            description: modelData.source + " · " + modelData.status + " · " + root.manager.date(modelData.created)
            ManagerButton {
                text: "Keep…"
                enabled: !root.manager.busy && modelData.status === "installed"
                onClicked: root.review({action: "keep", package: modelData.name}, "Keep " + modelData.name + "?", "Add this package to your permanent dotfiles package list and finish temporary tracking.")
            }
            ManagerButton {
                text: "Remove…"
                enabled: !root.manager.busy
                onClicked: root.review({action: "remove", package: modelData.name}, "Remove " + modelData.name + "?", "Uninstall this temporary package and finish tracking it. Dependencies are left for review in Cleanup. Packages required by another app cannot be removed.")
            }
        }
    }
}
