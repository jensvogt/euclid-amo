import QtQuick
import QtQuick.Controls

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

    readonly property var panels: root.dashboard.panels || []
    readonly property string dashboardName: root.dashboard.name || ""

    signal closeRequested(string name)

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
        height: 36
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
                // The range it was detached with, which is the range it keeps.
                text: "· " + (root.dashboard.range === "custom" ? "custom range" : (root.dashboard.range || "1h"))
                color: Theme.textMuted
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "· detached"
                color: Theme.textFaint
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

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
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }
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
