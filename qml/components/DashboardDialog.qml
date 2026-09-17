import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// The dashboard itself, rather than anything on it: what it is called, what window and refresh
// interval it opens with, and whether it should still exist.
//
// The name is the interesting one, because it is not only a label - a dashboard is stored as
// <name>.json and DashboardStore takes the name from the file rather than from inside it, so
// renaming is writing a new file and removing the old. That is why this dialog refuses a name
// already in use instead of saving over it: the store would do exactly as it was told, and the
// dashboard that was there would be gone with nothing to say so.
Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: 460
    padding: 24
    standardButtons: Dialog.NoButton

    // The dashboard as it currently stands.
    property string dashboardName: ""
    property string range: "1h"
    property int refreshSeconds: 30
    property int panelCount: 0
    // Every dashboard on disk, so a rename onto one of them can be refused.
    property var existingNames: []
    // The tables the top bar owns, passed in rather than repeated here.
    property var ranges: []
    property var refreshOptions: []

    signal dashboardSaved(string name, string range, int refreshSeconds)
    signal dashboardRemoved(string name)

    readonly property string typedName: nameField.text.trim()
    readonly property bool nameTaken: root.typedName !== root.dashboardName
                                      && root.existingNames.indexOf(root.typedName) >= 0
    readonly property bool nameUsable: root.typedName.length > 0 && !root.nameTaken

    function openFor(dashboard) {
        nameField.text = dashboard.name || ""
        rangeBox.currentIndex = Math.max(0, root.labels(root.ranges).indexOf(dashboard.range || "1h"))
        refreshBox.currentIndex = Math.max(0, root.refreshIndex(dashboard.refreshSeconds || 0))
        confirmingDelete = false
        root.open()
        // Focused and selected, because renaming is what this dialog is usually opened for and the
        // old name is what a rename replaces.
        nameField.forceActiveFocus()
        nameField.selectAll()
    }

    function labels(table) {
        const out = []
        for (const entry of table) out.push(entry.label)
        return out
    }

    function refreshIndex(seconds) {
        for (let i = 0; i < root.refreshOptions.length; ++i) {
            if (root.refreshOptions[i].seconds === seconds) return i
        }
        return 0
    }

    // Deleting is two clicks on one button rather than a second dialog on top of this one: the
    // wall it would throw away is behind both of them, and a confirmation that hides what it is
    // asking about is a confirmation nobody reads.
    property bool confirmingDelete: false

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    contentItem: Column {
        width: root.availableWidth
        spacing: 14

        Text {
            text: "Dashboard"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        Column {
            width: parent.width
            spacing: 3

            Text { text: "Name"; color: Theme.textFaint; font.pixelSize: 10 }
            TextField {
                id: nameField
                width: parent.width
                Material.theme: Material.Dark
                Material.accent: root.nameUsable ? Theme.accent : Theme.bad
                onAccepted: if (root.nameUsable) saveButton.clicked()
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.nameTaken
                text: "\"" + root.typedName + "\" is another dashboard already."
                color: Theme.bad
                font.pixelSize: 10
            }
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 14
            rowSpacing: 10

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Opens showing"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: rangeBox
                    width: parent.width
                    model: root.labels(root.ranges)
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Refreshes every"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: refreshBox
                    width: parent.width
                    model: root.labels(root.refreshOptions)
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.panelCount === 1 ? "1 panel on this dashboard."
                                        : root.panelCount + " panels on this dashboard."
            color: Theme.textFaint
            font.pixelSize: 10
        }

        Item {
            width: parent.width
            height: 36

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.confirmingDelete ? "Delete \"" + root.dashboardName + "\"?" : "Delete"
                color: deleteArea.containsMouse || root.confirmingDelete ? Theme.bad : Theme.textMuted
                font.pixelSize: 12
                MouseArea {
                    id: deleteArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.confirmingDelete) {
                            root.confirmingDelete = true
                            return
                        }
                        root.dashboardRemoved(root.dashboardName)
                        root.close()
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Text {
                    text: "Cancel"
                    color: cancelArea.containsMouse ? Theme.text : Theme.textMuted
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                Button {
                    id: saveButton
                    text: "Save"
                    highlighted: true
                    enabled: root.nameUsable
                    anchors.verticalCenter: parent.verticalCenter
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onClicked: {
                        root.dashboardSaved(root.typedName,
                                            root.labels(root.ranges)[rangeBox.currentIndex],
                                            root.refreshOptions[refreshBox.currentIndex].seconds)
                        root.close()
                    }
                }
            }
        }
    }
}
