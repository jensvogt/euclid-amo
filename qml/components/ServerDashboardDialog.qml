import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Picks one of the dashboards EMO is holding for the signed-in user.
//
// A list rather than a name to type: the point of storing a layout on the server is to open it on
// a machine that has never had it, which is exactly the machine whose owner cannot be expected to
// remember what it was called.
//
// Opened empty and filled when the answer arrives, rather than fetched first and opened after.
// A round trip to a gateway is long enough to look like a menu that did nothing, and a dialog that
// is already on screen saying "Loading…" is the difference between a slow answer and no answer.
Dialog {
    id: root

    // [{name, created, modified}], as EMO listed them - most recently modified first.
    property var items: []
    property bool loading: false
    property string error: ""
    property string userId: ""

    signal dashboardChosen(string name)

    modal: true
    anchors.centerIn: parent
    width: 460
    padding: 24
    standardButtons: Dialog.NoButton

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    function beginLoading() {
        root.items = []
        root.error = ""
        root.loading = true
        root.open()
    }

    function showItems(items) {
        root.items = items
        root.loading = false
    }

    function showError(message) {
        root.error = message
        root.loading = false
    }

    function formatInstant(iso) {
        const date = new Date(iso)
        return isNaN(date.getTime()) ? "—" : Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
    }

    contentItem: Column {
        width: root.availableWidth
        spacing: 14

        Text {
            text: root.userId.length > 0 ? "Dashboards in EMO · " + root.userId : "Dashboards in EMO"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            width: parent.width
            visible: root.loading
            text: "Loading…"
            color: Theme.textMuted
            font.pixelSize: 12
        }

        Text {
            width: parent.width
            visible: !root.loading && root.error.length > 0
            text: root.error
            color: Theme.warn
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: !root.loading && root.error.length === 0 && root.items.length === 0
            text: "Nothing saved yet. File ▸ Save to EMO puts this wall here."
            color: Theme.textMuted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: Math.min(260, Math.max(40, root.items.length * 40))
            visible: !root.loading && root.items.length > 0
            radius: 8
            color: Theme.background
            border.color: Theme.border
            border.width: 1
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 1
                model: root.items
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index

                    width: list.width
                    height: 40
                    color: list.currentIndex === row.index ? Theme.panelHeader
                           : (rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: Theme.text
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatInstant(row.modelData.modified)
                        color: Theme.textFaint
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: list.currentIndex = row.index
                        // The shortcut every list of things to open has.
                        onDoubleClicked: {
                            list.currentIndex = row.index
                            openButton.clicked()
                        }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 10

            Button {
                text: "Cancel"
                flat: true
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: root.close()
            }

            Button {
                id: openButton
                text: "Open"
                highlighted: true
                enabled: !root.loading && root.items.length > 0 && list.currentIndex >= 0
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    const chosen = root.items[list.currentIndex]
                    if (!chosen) return
                    root.close()
                    root.dashboardChosen(chosen.name)
                }
            }
        }
    }
}
