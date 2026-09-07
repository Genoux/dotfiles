import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs
import qs.config

Rectangle {
    id: root
    required property var manager
    property var selected: []
    property bool showingDetails: false
    readonly property var question: manager.prompt
    readonly property bool choices: ["choose", "filter"].includes(question.kind)
    readonly property bool textInput: ["input", "write"].includes(question.kind)
    readonly property var filtered: (question.options || []).filter(value => value.toLowerCase().includes(input.text.toLowerCase()))
    color: StyleOverlay.surface
    radius: StyleTokens.radiusMd
    visible: !!question.id
    MouseArea { anchors.fill: parent }

    function toggle(value) {
        if (!question.multiple) selected = [value]
        else if (selected.includes(value)) selected = selected.filter(item => item !== value)
        else if (!question.limit || selected.length < question.limit) selected = selected.concat([value])
    }

    function syncQuestion() {
        if (!question.id || question.id === content.questionId)
            return
        content.questionId = question.id
        showingDetails = false
        selected = (question.selected || []).filter(value => (question.options || []).includes(value))
        input.text = textInput ? question.value || "" : ""
        Qt.callLater(() => abortButton.forceActiveFocus())
    }

    onQuestionChanged: Qt.callLater(syncQuestion)
    Component.onCompleted: syncQuestion()

    Rectangle {
        id: content
        property string questionId: ""
        anchors.centerIn: parent
        width: Math.min(StyleManager.dialogWidth, parent.width - StyleManager.padding * 2)
        height: Math.min(root.height - StyleManager.padding * 2, promptColumn.implicitHeight + StyleManager.padding * 2)
        radius: StyleTokens.radiusMd
        color: Colors.base00
        border.width: StyleTokens.borderWidth
        border.color: StyleOverlay.borderSubtle
        ColumnLayout {
            id: promptColumn
            anchors.fill: parent
            anchors.margins: StyleManager.padding
            spacing: StyleTokens.space12
            ManagerLabel {
                Layout.fillWidth: true
                text: root.manager.job.title || "Operation needs your input"
                color: StyleManager.textColor
            }
            ManagerLabel {
                Layout.fillWidth: true
                text: root.question.title || ""
                font.pixelSize: StyleTokens.fontSizeLg
                font.weight: Font.DemiBold
            }
            ManagerInput {
                id: input
                Layout.fillWidth: true
                visible: root.choices || root.textInput
                placeholderText: root.choices ? "Search options" : "Enter a value"
            }
            RowLayout {
                visible: root.choices && !!root.question.multiple
                Layout.fillWidth: true
                ManagerLabel { Layout.fillWidth: true; text: root.selected.length + " selected"; color: StyleManager.textColor }
                ManagerButton { text: "Select visible"; enabled: !root.question.limit; onClicked: root.selected = Array.from(new Set(root.selected.concat(root.filtered))) }
                ManagerButton { text: "Clear"; onClicked: root.selected = [] }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !!root.question.context
                ManagerButton { text: "Choices"; active: !root.showingDetails; onClicked: root.showingDetails = false }
                ManagerButton { text: "Operation details"; active: root.showingDetails; onClicked: root.showingDetails = true }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: StyleManager.rowHeight * 5
                Layout.fillHeight: true
                visible: root.showingDetails
                contentHeight: contextText.implicitHeight
                clip: true
                Controls.ScrollBar.vertical: Controls.ScrollBar {}
                ManagerLabel {
                    id: contextText
                    width: parent.width
                    text: String(root.question.context || "").replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "")
                    font.family: StyleTokens.fontMono
                }
            }
            ListView {
                id: options
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(StyleManager.rowHeight * 5, contentHeight)
                Layout.minimumHeight: root.choices ? StyleManager.rowHeight : 0
                Layout.fillHeight: true
                visible: root.choices && !root.showingDetails
                model: root.filtered
                spacing: StyleTokens.space4
                clip: true
                Controls.ScrollBar.vertical: Controls.ScrollBar {}
                delegate: ManagerRow {
                    required property string modelData
                    width: options.width - StyleTokens.space12
                    title: modelData
                    ManagerButton {
                        text: root.selected.includes(modelData) ? "Selected" : "Select"
                        active: root.selected.includes(modelData)
                        onClicked: root.toggle(modelData)
                    }
                }
            }
            ManagerLabel {
                Layout.fillWidth: true
                visible: root.manager.error.length > 0
                text: root.manager.error
                color: StyleManager.textColor
            }
            RowLayout {
                Layout.fillWidth: true
                ManagerButton {
                    id: abortButton
                    text: "Cancel operation"
                    enabled: !root.manager.answering
                    onClicked: root.manager.answer({cancel: true})
                }
                Item { Layout.fillWidth: true }
                ManagerButton {
                    visible: root.question.kind === "confirm"
                    text: root.question.options?.[1] || "Skip"
                    enabled: !root.manager.answering
                    onClicked: root.manager.answer({accepted: false})
                }
                ManagerButton {
                    text: root.question.kind === "confirm" ? root.question.options?.[0] || "Continue" : "Continue"
                    enabled: !root.manager.answering && (!root.choices || root.question.multiple || root.selected.length === 1)
                    onClicked: root.manager.answer(root.question.kind === "confirm" ? {accepted: true} : {values: root.textInput ? [input.text] : root.selected})
                }
            }
        }
    }
}
