import QtQuick
import QtQuick.Layouts
import qs
import qs.config

Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property string detail: ""
    default property alias actions: actionsLayout.data
    implicitHeight: Math.max(StyleManager.rowHeight, labels.implicitHeight + StyleTokens.space12 * 2)
    color: StyleTokens.transparent

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: StyleTokens.borderWidth
        color: StyleOverlay.borderSubtle
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: StyleTokens.space12
        anchors.bottomMargin: StyleTokens.space12
        spacing: StyleTokens.space20
        ColumnLayout {
            id: labels
            Layout.fillWidth: true
            spacing: StyleTokens.space4
            ManagerLabel {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.Medium
            }
            ManagerLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.description
                color: StyleManager.textColor
            }
        }
        ManagerLabel {
            visible: text.length > 0
            text: root.detail
            color: StyleManager.textColor
        }
        RowLayout { id: actionsLayout; spacing: StyleTokens.space6 }
    }
}
