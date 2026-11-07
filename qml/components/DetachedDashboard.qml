import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// One dashboard in a window of its own.
//
// What it is for is the second monitor: a wall somebody wants left up while they work in the main
// window on another one. So it is a window rather than a dialog - it has its own place on the
// desktop, it is not modal, and closing it changes nothing but itself.
//
// It shows the dashboard as it stood when it was detached. Deliberately: the copy is taken on
// detaching and nothing writes back into it, so rearranging panels or switching dashboards in the
// main window cannot reach in here and change what somebody is watching. Detaching again picks up
// whatever has changed since.
//
// The panels are locked. Editing belongs in the one window that owns the file on disk; two windows
// writing the same dashboard would be two windows disagreeing about it.
Window {
    id: root

    // The dashboard, as a plain object: {name, range, panels: [...]}.
    property var dashboard: ({})
    // The application's one map of panel data, keyed by panel id - the same one the main window
    // draws from, which is why nothing here fetches anything: Main refreshes detached dashboards
    // on the same tick as the one on screen.
    property var dataById: ({})
    property string lastUpdated: "—"
    property bool busy: false

    // This window's own range and its own refresh interval, neither of which is written back
    // anywhere: the dashboard file belongs to the main window, and the application's auto-refresh
    // setting belongs to the application. A detached wall is a view, and these are how it is
    // looked at - one monitor on the last 15 minutes while another watches the week.
    property string range: root.dashboard.range || "1h"
    property int refreshSeconds: 0

    readonly property var currentRange: Ranges.entryFor(root.range, root.dashboard.customFrom || "",
                                                        root.dashboard.customTo || "")

    readonly property var panels: root.dashboard.panels || []
    readonly property string dashboardName: root.dashboard.name || ""

    signal closeRequested(string name)
    // Asked for by the toolbar, answered by Main: it owns the client and the one map of panel data.
    signal refreshRequested(string name)

    width: 1200
    height: 800
    minimumWidth: 480
    minimumHeight: 320
    visible: true
    color: Theme.background
    title: "Euclid AMO · " + root.dashboardName

    onClosing: root.closeRequested(root.dashboardName)

    Rectangle {
        id: header
        width: parent.width
        height: 44
        color: Theme.panelHeader

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: root.dashboardName
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "· detached"
                color: Theme.textFaint
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // The same controls the main toolbar carries, over this window's own copy: the six ranges,
        // how often it re-asks, and a refresh now. Everything else on that bar - the dashboard
        // picker, the padlock, add panel, settings - belongs to the window that owns the file.
        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            BusyIndicator {
                width: 14
                height: 14
                running: root.busy
                visible: root.busy
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Updated " + root.lastUpdated
                color: Theme.textFaint
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }

            RangeButtons {
                anchors.verticalCenter: parent.verticalCenter
                range: root.range
                // Only while this window is on one. There is no picker here, so a custom window
                // can be left and not returned to; the chip says where it is until then.
                showCustom: root.range === "custom"
                customSeconds: root.range === "custom" ? root.currentRange.seconds : 0
                onRangeSelected: (label) => {
                    root.range = label
                    root.refreshRequested(root.dashboardName)
                }
            }

            ComboBox {
                id: refreshBox
                width: 90
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                model: RefreshIntervals.shortLabels()
                font.pixelSize: 11
                Material.theme: Material.Dark
                Material.accent: Theme.accent

                ToolTip.visible: hovered
                ToolTip.text: "How often this window re-asks. The main window keeps its own."
                ToolTip.delay: 600

                onActivated: root.refreshSeconds = RefreshIntervals.secondsAt(currentIndex)

                // Assigned rather than bound: a ComboBox writes its own currentIndex while it
                // populates, and a binding would be overwritten the first time it did.
                Component.onCompleted: refreshBox.currentIndex = RefreshIntervals.indexOf(root.refreshSeconds)
            }

            Rectangle {
                width: 28
                height: 28
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: refreshArea.containsMouse ? Theme.panelHeader : "transparent"
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⟳"
                    color: Theme.textMuted
                    font.pixelSize: 13
                }

                ToolTip.visible: refreshArea.containsMouse
                ToolTip.text: "Refresh this window now"
                ToolTip.delay: 400

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshRequested(root.dashboardName)
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }
    }

    // This window's own beat. The application's timer refreshes the main wall; a detached window
    // that followed it could not be set to anything else, which is half the point of the toolbar
    // above.
    Timer {
        interval: Math.max(5, root.refreshSeconds) * 1000
        running: root.refreshSeconds > 0
        repeat: true
        onTriggered: root.refreshRequested(root.dashboardName)
    }

    Flickable {
        id: wall
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: grid.contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        DashboardGrid {
            id: grid
            width: wall.width
            panels: root.panels
            dataById: root.dataById
            // Locked, for the reason at the top of the file.
            editing: false
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.panels.length === 0
        text: "This dashboard has no panels."
        color: Theme.textMuted
        font.pixelSize: 12
    }
}
