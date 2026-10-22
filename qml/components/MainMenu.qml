import QtQuick
import QtQuick.Controls

// The window's menu bar.
//
// Styled rather than left to the Material theme. Material Dark draws its own greys - #303030 and
// upwards - which above Theme.background reads as a strip borrowed from another application and
// laid on top of this one. The palette here is the wall's own, and the bar carries no fill of its
// own so that it and the TimeRangeBar below it read as one header, divided from the wall by the
// single rule that is already there.
//
// Only signals leave here. What "save" and "exit" mean belongs to the window that owns the
// dashboard, the same way TimeRangeBar hands its buttons back rather than acting on them itself.
MenuBar {
    id: root

    signal saveRequested()
    signal saveToServerRequested()
    signal openFromServerRequested()
    signal exitRequested()

    // Greys out the two server entries when there is no session to reach EMO with, rather than
    // hiding them: a menu whose shape changes with the state of a connection is a menu somebody
    // cannot learn, and "Save to EMO" absent reads as "this build cannot" rather than "sign in".
    property bool signedIn: false
    // Shown beside them, so that what "my dashboards" means is on screen at the moment of saving
    // rather than something to be remembered from the sign-in dialog.
    property string userId: ""

    leftPadding: 8
    topPadding: 2
    bottomPadding: 2

    background: Rectangle {
        color: Theme.background
    }

    // A menu row: its label on the left, the keystroke that reaches it without the menu on the
    // right. The accelerator is written out rather than read back off a Shortcut, because a
    // QKeySequence built from StandardKey arrives in QML as a number and "Ctrl+S" is what somebody
    // reading the menu needs to see.
    component FileItem: MenuItem {
        id: item

        property string accelerator: ""

        implicitHeight: 30
        // Wide enough for the longest row, which is "Save to EMO as <user>" beside its
        // accelerator; Menu sizes itself to the widest item it holds.
        implicitWidth: 300

        contentItem: Item {
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: item.text
                color: item.enabled ? Theme.text : Theme.textFaint
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: item.accelerator
                color: Theme.textFaint
                font.pixelSize: 11
            }
        }

        background: Rectangle {
            color: item.highlighted ? Theme.panelHeader : "transparent"
        }
    }

    // The top-level titles: "File", and whatever joins it later.
    delegate: MenuBarItem {
        id: barItem

        implicitHeight: 26
        padding: 10

        contentItem: Text {
            text: barItem.text
            color: Theme.text
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 5
            // Open and merely hovered are drawn the same on purpose: the menu hanging below says
            // which title is open far more plainly than a second highlight behind it would, and
            // two states competing at that size only reads as flicker while the pointer travels.
            color: barItem.highlighted || barItem.hovered ? Theme.panelHeader : "transparent"
        }
    }

    Menu {
        id: fileMenu

        title: "File"
        padding: 6

        background: Rectangle {
            implicitWidth: 300
            radius: 8
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        FileItem {
            text: "Save"
            accelerator: "Ctrl+S"
            onTriggered: root.saveRequested()
        }

        FileItem {
            // Names the user it will save under, because that is the whole of what distinguishes
            // this from the entry above it - the same layout, somewhere a different machine can
            // reach, under whoever is signed in.
            text: "Save to EMO"
            accelerator: "Ctrl+Shift+S"
            enabled: root.signedIn
            onTriggered: root.saveToServerRequested()
        }

        FileItem {
            text: "Load from EMO…"
            enabled: root.signedIn
            onTriggered: root.openFromServerRequested()
        }

        MenuSeparator {
            padding: 0
            topPadding: 4
            bottomPadding: 4
            contentItem: Rectangle {
                implicitWidth: 280
                implicitHeight: 1
                color: Theme.border
            }
        }

        FileItem {
            text: "Exit"
            onTriggered: root.exitRequested()
        }
    }
}
