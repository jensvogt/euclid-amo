import QtQuick
import QtQuick.Controls

// The ranges as one segmented control rather than a dropdown: on a wall these are the control
// people reach for most, and a dropdown costs two clicks to answer "and the last six hours?".
//
// Shared by the main toolbar and every detached window's, which is the whole reason it is its own
// file: two copies of six buttons would be two places to fix a tooltip.
Row {
    id: root

    property string range: "1h"
    // Shown as a seventh, unclickable chip while the dashboard is on a custom window, so a wall
    // that is not on any of the six does not look as though it is on none of them.
    property bool showCustom: false
    property real customSeconds: 0
    property int buttonWidth: 42
    property int buttonHeight: 28

    signal rangeSelected(string label)

    spacing: 0

    Repeater {
        model: Ranges.table

        delegate: Rectangle {
            id: rangeButton
            required property var modelData

            width: root.buttonWidth
            height: root.buttonHeight
            color: root.range === rangeButton.modelData.label ? Theme.accent
                   : (rangeArea.containsMouse ? Theme.panelHeader : "transparent")
            border.color: Theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: rangeButton.modelData.label
                color: root.range === rangeButton.modelData.label ? "white" : Theme.textMuted
                font.pixelSize: 11
            }

            // What the button is short for, and what a point on the chart will be: "6h" says
            // nothing about whether the line is drawn from five-minute readings or from daily
            // ones, and that is the difference between seeing a spike and not.
            ToolTip.visible: rangeArea.containsMouse
            ToolTip.text: Ranges.rangeTip(rangeButton.modelData)
            ToolTip.delay: 400

            MouseArea {
                id: rangeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.rangeSelected(rangeButton.modelData.label)
            }
        }
    }

    Rectangle {
        id: customChip
        visible: root.showCustom
        width: 62
        height: root.buttonHeight
        color: root.range === "custom" ? Theme.accent : "transparent"
        border.color: Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.customSeconds > 0 ? Ranges.formatSpan(root.customSeconds) + " ⋯" : "custom"
            color: root.range === "custom" ? "white" : Theme.textMuted
            font.pixelSize: 11
        }

        ToolTip.visible: customArea.containsMouse
        ToolTip.text: root.customSeconds > 0
                      ? "A window somebody typed\n"
                        + Ranges.tierWords(root.customSeconds,
                                           Ranges.resolutionForSeconds(root.customSeconds))
                      : "A window somebody typed"
        ToolTip.delay: 400

        MouseArea {
            id: customArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }
}
