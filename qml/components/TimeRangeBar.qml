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
    // Only meaningful while range is "custom": the two ends of a window somebody typed, as ISO
    // instants. A relative range is a duration ending now; this one is two fixed moments, which is
    // the whole difference and the reason it cannot live in the table below.
    property string customFrom: ""
    property string customTo: ""
    property bool editing: false
    property string dashboardName: ""
    property var dashboardNames: []

    readonly property var ranges: [
        {label: "15m", seconds: 900, resolution: "RAW"},
        {label: "1h", seconds: 3600, resolution: "RAW"},
        {label: "6h", seconds: 21600, resolution: "RAW"},
        {label: "24h", seconds: 86400, resolution: "HOUR"},
        {label: "7d", seconds: 604800, resolution: "HOUR"},
        {label: "30d", seconds: 2592000, resolution: "DAY"}
    ]

    // The name DashboardStore::starterDashboard() gives the wall a first run creates, and the one
    // most installations keep as their front page - so it holds the top of the list rather than
    // whatever position its initial letter earns it. Everything else is alphabetical.
    readonly property string primaryDashboard: "Overview"

    readonly property var orderedDashboardNames: {
        const rest = []
        let primaryPresent = false
        for (const name of root.dashboardNames) {
            if (name === root.primaryDashboard) primaryPresent = true
            else rest.push(name)
        }
        // localeCompare rather than the default sort, which orders by code point and so files
        // every capital ahead of every lower-case letter: "Zulu" before "alpha".
        rest.sort((left, right) => left.localeCompare(right))
        return primaryPresent ? [root.primaryDashboard].concat(rest) : rest
    }

    readonly property real customSpanSeconds: {
        const from = Date.parse(root.customFrom)
        const to = Date.parse(root.customTo)
        if (isNaN(from) || isNaN(to) || to <= from) return 0
        return (to - from) / 1000
    }

    // Which tier a window of this length should be read from, taken from the table rather than
    // written out again: the longest range that fits inside it answers for it.
    //
    // That way a custom window lands on the same tier as the button of the same length - a day
    // typed in reads HOUR exactly as 24h does - and the ones in between inherit from the shorter
    // neighbour rather than the longer. Nine hours asked of the HOUR tier is nine points; asked of
    // RAW it is a hundred and eight, which is what somebody picking nine hours wanted to see.
    function resolutionForSeconds(seconds) {
        let resolution = root.ranges[0].resolution
        for (const entry of root.ranges) {
            if (entry.seconds <= seconds) resolution = entry.resolution
        }
        return resolution
    }

    // Short enough for a button: "45m", "6h", "3d".
    function formatSpan(seconds) {
        if (seconds >= 86400) return Math.round(seconds / 86400) + "d"
        if (seconds >= 3600) return Math.round(seconds / 3600) + "h"
        return Math.max(1, Math.round(seconds / 60)) + "m"
    }

    function formatInstant(iso) {
        const date = new Date(iso)
        return isNaN(date.getTime()) ? "—" : Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
    }

    readonly property var currentRange: {
        if (root.range === "custom" && root.customSpanSeconds > 0) {
            return {label: "custom", seconds: root.customSpanSeconds,
                    resolution: root.resolutionForSeconds(root.customSpanSeconds)}
        }
        for (const entry of root.ranges) {
            if (entry.label === root.range) return entry
        }
        return root.ranges[1]
    }

    signal rangeSelected(string label)
    signal customRangeRequested()
    signal refreshRequested()
    signal editingToggled()
    signal addPanelRequested()
    signal dashboardSelected(string name)
    signal newDashboardRequested()
    signal editDashboardRequested()
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
            model: root.orderedDashboardNames
            Material.theme: Material.Dark
            Material.accent: Theme.accent
            // Assigned rather than bound: a ComboBox clobbers currentIndex while it populates its
            // own model, and a binding here would be overwritten the first time the list changes.
            onActivated: root.dashboardSelected(currentText)

            Connections {
                target: root
                function onDashboardNameChanged() {
                    dashboardBox.currentIndex = root.orderedDashboardNames.indexOf(root.dashboardName)
                }
                function onOrderedDashboardNamesChanged() {
                    dashboardBox.currentIndex = root.orderedDashboardNames.indexOf(root.dashboardName)
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

        // Beside the dashboard it acts on rather than among the wall's own controls on the right:
        // this edits which dashboard this is, not what the wall is currently showing.
        Text {
            text: "Edit"
            color: editDashboardArea.containsMouse ? Theme.accent : Theme.textMuted
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                id: editDashboardArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editDashboardRequested()
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

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

            // Part of the same segmented control rather than a button beside it: it answers the
            // same question as the six to its left, just without assuming the answer ends now.
            Rectangle {
                id: customButton

                readonly property bool active: root.range === "custom" && root.customSpanSeconds > 0

                width: 62
                height: 28
                color: customButton.active ? Theme.accent
                       : (customArea.containsMouse ? Theme.panelHeader : "transparent")
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    // The span once there is one, because "custom" on a wall read from across a
                    // room says nothing about what is on it. The exact ends are a hover away.
                    text: customButton.active ? root.formatSpan(root.customSpanSeconds) + " ⋯" : "Custom…"
                    color: customButton.active ? "white" : Theme.textMuted
                    font.pixelSize: 11
                }

                ToolTip.visible: customArea.containsMouse
                ToolTip.text: customButton.active
                              ? root.formatInstant(root.customFrom) + "  →  " + root.formatInstant(root.customTo)
                              : "Pick a start and an end"
                ToolTip.delay: 400

                MouseArea {
                    id: customArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.customRangeRequested()
                }
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
