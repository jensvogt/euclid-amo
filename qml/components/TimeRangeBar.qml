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
    // The application's one auto-refresh interval, shown here as a shortcut to the setting rather
    // than as a second copy of it: picking one writes to the same place Settings does.
    property int refreshSeconds: 0
    // Only meaningful while range is "custom": the two ends of a window somebody typed, as ISO
    // instants. A relative range is a duration ending now; this one is two fixed moments, which is
    // the whole difference and the reason it cannot live in the table below.
    property string customFrom: ""
    property string customTo: ""
    property bool editing: false
    property string dashboardName: ""
    property var dashboardNames: []

    // The table itself lives in the Ranges singleton now, because the detached windows carry the
    // same six buttons. These stay as the bar's own surface so that Main and the dialogs that read
    // "topBar.ranges" or call "topBar.rangeFor(...)" go on working.
    readonly property var ranges: Ranges.table

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

    // All of these moved into the Ranges singleton when the detached windows grew a toolbar of
    // their own. They stay here as one-line forwards so that Main, the dialogs and the panels that
    // already call them through the bar do not have to care where the table lives.
    function resolutionForSeconds(seconds) { return Ranges.resolutionForSeconds(seconds) }
    function bucketWords(resolution) { return Ranges.bucketWords(resolution) }
    function tierWords(seconds, resolution) { return Ranges.tierWords(seconds, resolution) }
    function spanWords(seconds) { return Ranges.spanWords(seconds) }
    function rangeTip(entry) { return Ranges.rangeTip(entry) }
    function formatSpan(seconds) { return Ranges.formatSpan(seconds) }
    function rangeFor(range, customFrom, customTo) { return Ranges.entryFor(range, customFrom, customTo) }

    function formatInstant(iso) {
        const date = new Date(iso)
        return isNaN(date.getTime()) ? "—" : Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
    }

    readonly property var currentRange: Ranges.entryFor(root.range, root.customFrom, root.customTo)

    signal rangeSelected(string label)
    signal detachRequested()
    signal customRangeRequested()
    signal refreshRequested()
    signal editingToggled()
    signal addPanelRequested()
    signal dashboardSelected(string name)
    signal newDashboardRequested()
    signal editDashboardRequested()
    signal aboutRequested()
    signal refreshSelected(int seconds)
    signal settingsRequested()

    implicitHeight: 52

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // The mark, drawn rather than loaded: it is a rounded square, and an image would mean
        // carrying qtsvg into a statically linked binary for one shape. Clicking it opens the
        // about box, which is where a mark in the corner of a window usually leads.
        Rectangle {
            id: mark

            width: 26
            height: 26
            radius: 7
            color: markArea.containsMouse ? Qt.rgba(0.49, 0.36, 1, 0.18) : "transparent"
            border.color: "#7c5cff"
            border.width: 2
            anchors.verticalCenter: parent.verticalCenter

            ToolTip.visible: markArea.containsMouse
            ToolTip.text: "About Euclid AMO"
            ToolTip.delay: 500

            MouseArea {
                id: markArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.aboutRequested()
            }
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

            // The six relative ranges, shared with every detached window's toolbar.
            RangeButtons {
                range: root.range
                onRangeSelected: (label) => root.rangeSelected(label)
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
                // The same two lines the range buttons carry, over the window somebody typed: a
                // custom span lands on a tier exactly as a button does, and which one is not
                // obvious from two dates.
                ToolTip.text: customButton.active
                              ? root.formatInstant(root.customFrom) + "  →  " + root.formatInstant(root.customTo)
                                + "\n" + root.tierWords(root.customSpanSeconds,
                                                        root.resolutionForSeconds(root.customSpanSeconds))
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

        // Back beside the manual refresh, where it was before the interval became one setting for
        // the application: this is the control somebody reaches for when a wall is being watched,
        // and sending them through Settings for it was two clicks too many.
        ComboBox {
            id: refreshBox
            // Wide enough for the longest label plus Material's indicator; at 74 the "m" of
            // "15m" was cut in half.
            width: 90
            height: 30
            anchors.verticalCenter: parent.verticalCenter
            model: RefreshIntervals.shortLabels()
            Material.theme: Material.Dark
            Material.accent: Theme.accent

            ToolTip.visible: hovered
            ToolTip.text: "How often the wall re-asks - the same setting Settings holds"
            ToolTip.delay: 600

            onActivated: root.refreshSelected(RefreshIntervals.secondsAt(currentIndex))

            // Assigned rather than bound: a ComboBox writes its own currentIndex while it
            // populates, and a binding would be overwritten the first time it did. The
            // Connections keeps it in step with the setting being changed in the dialog.
            Component.onCompleted: refreshBox.currentIndex = RefreshIntervals.indexOf(root.refreshSeconds)

            Connections {
                target: root
                function onRefreshSecondsChanged() {
                    refreshBox.currentIndex = RefreshIntervals.indexOf(root.refreshSeconds)
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
        ToolButtonText {
            label: "⧉"
            tip: "Open this dashboard in a window of its own"
            onActivated: root.detachRequested()
        }
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
