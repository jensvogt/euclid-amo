import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The wall's own controls: which dashboard, over what window, how often, and whether it can be
// rearranged.
//
// The ranges double as resolution hints, which is why they are a table rather than a list of
// durations. EMO stores three tiers - RAW five-minute buckets, HOUR, DAY - and asking for a week of
// RAW is both slower and less readable than asking for a week of HOUR: the same line drawn from
// 2,016 points instead of 168.
Item {
    id: root

    property string range: "1h"
    property int refreshSeconds: 30
    property bool editing: false
    property string dashboardName: ""
    property var dashboardNames: []
    property string lastUpdated: "—"
    property bool busy: false

    readonly property var ranges: [
        {label: "15m", seconds: 900, resolution: "RAW"},
        {label: "1h", seconds: 3600, resolution: "RAW"},
        {label: "6h", seconds: 21600, resolution: "RAW"},
        {label: "24h", seconds: 86400, resolution: "HOUR"},
        {label: "7d", seconds: 604800, resolution: "HOUR"},
        {label: "30d", seconds: 2592000, resolution: "DAY"}
    ]

    readonly property var currentRange: {
        for (const entry of root.ranges) {
            if (entry.label === root.range) return entry
        }
        return root.ranges[1]
    }

    signal rangeSelected(string label)
    signal refreshSelected(int seconds)
    signal refreshRequested()
    signal editingToggled()
    signal addPanelRequested()
    signal dashboardSelected(string name)
    signal newDashboardRequested()
    signal settingsRequested()

    implicitHeight: 52

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
            width: 26
            height: 26
            radius: 7
            color: "transparent"
            border.color: "#7c5cff"
            border.width: 2
            anchors.verticalCenter: parent.verticalCenter
        }

        ComboBox {
            id: dashboardBox
            width: 220
            height: 30
            anchors.verticalCenter: parent.verticalCenter
            model: root.dashboardNames
            Material.theme: Material.Dark
            Material.accent: Theme.accent
            // Assigned rather than bound: a ComboBox clobbers currentIndex while it populates its
            // own model, and a binding here would be overwritten the first time the list changes.
            onActivated: root.dashboardSelected(currentText)

            Connections {
                target: root
                function onDashboardNameChanged() {
                    dashboardBox.currentIndex = root.dashboardNames.indexOf(root.dashboardName)
                }
                function onDashboardNamesChanged() {
                    dashboardBox.currentIndex = root.dashboardNames.indexOf(root.dashboardName)
                }
            }
        }

        Text {
            text: "+ New"
            color: newArea.containsMouse ? Theme.accent : Theme.textMuted
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                id: newArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.newDashboardRequested()
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            text: root.busy ? "Refreshing…" : "Updated " + root.lastUpdated
            color: root.busy ? Theme.accent : Theme.textFaint
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        // The ranges, as one segmented control rather than a dropdown: on a wall these are the
        // control people reach for most, and a dropdown costs two clicks to answer "and the last
        // six hours?".
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
                model: root.ranges

                delegate: Rectangle {
                    id: rangeButton
                    required property var modelData

                    width: 42
                    height: 28
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

                    MouseArea {
                        id: rangeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rangeSelected(rangeButton.modelData.label)
                    }
                }
            }
        }

        ComboBox {
            id: refreshBox
            width: 96
            height: 30
            anchors.verticalCenter: parent.verticalCenter
            model: ["off", "10s", "30s", "1m", "5m"]
            Material.theme: Material.Dark
            Material.accent: Theme.accent
            onActivated: {
                const seconds = [0, 10, 30, 60, 300]
                root.refreshSelected(seconds[currentIndex])
            }
            Component.onCompleted: {
                const seconds = [0, 10, 30, 60, 300]
                refreshBox.currentIndex = Math.max(0, seconds.indexOf(root.refreshSeconds))
            }
        }

        ToolButtonText { label: "⟳"; tip: "Refresh now (F5)"; onActivated: root.refreshRequested() }
        ToolButtonText {
            label: root.editing ? "🔓" : "🔒"
            tip: root.editing ? "Lock the wall" : "Unlock to rearrange"
            highlighted: root.editing
            onActivated: root.editingToggled()
        }
        ToolButtonText { label: "＋"; tip: "Add a panel"; enabled: root.editing; onActivated: root.addPanelRequested() }
        ToolButtonText { label: "⚙"; tip: "Settings"; onActivated: root.settingsRequested() }
    }

    // A small square button with a glyph - four of them in a row, and a Button with Material
    // padding would be twice the size for the same tap target.
    component ToolButtonText: Rectangle {
        id: toolButton
        property string label: ""
        property string tip: ""
        property bool highlighted: false
        signal activated()

        width: 32
        height: 32
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        // "enabled" is Item's own, not one declared here: it already stops the MouseArea below
        // from firing, so redeclaring it would shadow the thing doing the work.
        color: toolButton.highlighted ? Theme.accent
               : (toolArea.containsMouse ? Theme.panelHeader : "transparent")
        border.color: Theme.border
        border.width: 1
        opacity: toolButton.enabled ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            text: toolButton.label
            color: toolButton.highlighted ? "white" : Theme.textMuted
            font.pixelSize: 14
        }

        ToolTip.visible: toolArea.containsMouse && toolButton.tip.length > 0
        ToolTip.text: toolButton.tip
        ToolTip.delay: 400

        MouseArea {
            id: toolArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toolButton.activated()
        }
    }
}
