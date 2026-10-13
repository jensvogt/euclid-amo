import QtQuick

// The line along the foot of the window: which dashboard is up, who is signed in, and how fresh
// the numbers are.
//
// "Last updated" lives here rather than in the top bar it used to share with the range buttons.
// The question a wall has to answer from across a room is whether the numbers are still arriving,
// and that is a property of the window rather than of the controls - so it belongs on a line of
// its own, at the edge, where it is not competing with anything that gets clicked.
Item {
    id: root

    property string dashboardName: ""
    property int panelCount: 0
    property string userName: ""
    property string namespaceName: ""
    // Formatted by the caller, which is the only thing that knows when a fetch came back.
    property string lastUpdated: "—"
    property bool busy: false

    implicitHeight: 26

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.border
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        color: Theme.panelHeader
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            text: root.dashboardName
            color: Theme.textMuted
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "·"
            color: Theme.border
            font.pixelSize: 11
            visible: root.dashboardName.length > 0
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.panelCount === 1 ? "1 panel" : root.panelCount + " panels"
            color: Theme.textFaint
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            // Both or neither: a namespace without the user it was chosen by says half of who is
            // being shown this.
            text: root.userName.length > 0 && root.namespaceName.length > 0
                  ? root.userName + " @ " + root.namespaceName : root.userName
            color: Theme.textFaint
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "·"
            color: Theme.border
            font.pixelSize: 11
            visible: root.userName.length > 0
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            // Accented while fetching, so a wall nobody is sitting at still shows that it is alive
            // without anybody reading the clock.
            text: root.busy ? "Refreshing…" : "Last updated " + root.lastUpdated
            color: root.busy ? Theme.accent : Theme.textMuted
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
