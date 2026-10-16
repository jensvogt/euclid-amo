import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// What this is and which build of it is running.
//
// The version matters more here than in most applications: a wall is left running for weeks on a
// screen nobody signs into, and the first question about anything odd on it is which build put it
// there. So the version, the day it was built and the Qt underneath it are all on one line that
// can be read out over a telephone.
Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: 420
    padding: 24
    standardButtons: Dialog.NoButton

    readonly property string projectUrl: "https://github.com/jensvogt/euclid-amo"

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    contentItem: Column {
        width: root.availableWidth
        spacing: 14

        Row {
            width: parent.width
            spacing: 14

            // The same mark as the corner of the window it was opened from, larger.
            Rectangle {
                width: 44
                height: 44
                radius: 12
                color: "transparent"
                border.color: "#7c5cff"
                border.width: 3
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Euclid AMO"
                    color: Theme.text
                    font.pixelSize: 18
                    font.bold: true
                }
                Text {
                    text: "Application monitoring"
                    color: Theme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "A wall of panels over euclid's monitoring module. A dashboard is a list of "
                  + "panels, each one a query against a metric and a way of drawing it."
            color: Theme.textMuted
            font.pixelSize: 11
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 12
            rowSpacing: 4

            Text { text: "Version"; color: Theme.textFaint; font.pixelSize: 11 }
            Text { text: appVersion; color: Theme.text; font.pixelSize: 11 }

            Text { text: "Built"; color: Theme.textFaint; font.pixelSize: 11 }
            Text { text: buildDate; color: Theme.text; font.pixelSize: 11 }

            Text { text: "Qt"; color: Theme.textFaint; font.pixelSize: 11 }
            Text { text: qtVersion; color: Theme.text; font.pixelSize: 11 }
        }

        Text {
            width: parent.width
            text: root.projectUrl
            color: linkArea.containsMouse ? Theme.accent : Theme.textMuted
            font.pixelSize: 11
            font.underline: linkArea.containsMouse
            elide: Text.ElideRight

            MouseArea {
                id: linkArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hands the address to whatever the desktop opens addresses with. On a wall with
                // no browser installed nothing happens, which is better than an error about it.
                onClicked: Qt.openUrlExternally(root.projectUrl)
            }
        }

        Item {
            width: parent.width
            height: 36

            Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Close"
                flat: true
                Material.theme: Material.Dark
                onClicked: root.close()
            }
        }
    }
}
