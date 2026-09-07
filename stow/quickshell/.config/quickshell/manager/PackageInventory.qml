import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config

ColumnLayout {
    id: root
    required property var manager
    property int filterIndex: 0
    property int pageIndex: 0
    readonly property var filtered: (manager.overview.packages || []).filter(item =>
        (filterIndex === 0 ? item.state !== "missing" : filterIndex === 1 ? ["tracked", "missing"].includes(item.state) : filterIndex === 2 ? item.state === "missing" : item.state === "unlisted")
        && item.name.toLowerCase().includes(search.text.toLowerCase()))
    readonly property int pageSize: 30
    spacing: StyleTokens.space8
    ManagerInput {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search package names"
        onTextChanged: root.pageIndex = 0
    }
    SegmentedControl {
        selectedTextColor: StyleManager.textColor
        textColor: StyleManager.textColor
        Layout.fillWidth: true
        labels: ["Installed", "Tracked", "Missing", "Unlisted"]
        currentIndex: root.filterIndex
        onSegmentSelected: index => { root.filterIndex = index; root.pageIndex = 0 }
        activeFocusOnTab: true
        Keys.onLeftPressed: { root.filterIndex = Math.max(0, root.filterIndex - 1); root.pageIndex = 0 }
        Keys.onRightPressed: { root.filterIndex = Math.min(3, root.filterIndex + 1); root.pageIndex = 0 }
    }
    ManagerLabel {
        Layout.fillWidth: true
        text: root.filtered.length + " packages · hardware and temporary exclusions remain separate. Use Reconcile packages above to review changes."
        color: StyleManager.textColor
    }
    Repeater {
        model: root.filtered.slice(root.pageIndex * root.pageSize, (root.pageIndex + 1) * root.pageSize)
        ManagerRow {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.name
            description: modelData.version || "Not installed"
            detail: modelData.state + " · " + modelData.source
        }
    }
    RowLayout {
        Layout.fillWidth: true
        ManagerButton {
            text: "Previous"
            enabled: root.pageIndex > 0
            onClicked: root.pageIndex--
        }
        ManagerLabel { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Page " + (root.pageIndex + 1) + " of " + Math.max(1, Math.ceil(root.filtered.length / root.pageSize)) }
        ManagerButton {
            text: "Next"
            enabled: (root.pageIndex + 1) * root.pageSize < root.filtered.length
            onClicked: root.pageIndex++
        }
    }
}
