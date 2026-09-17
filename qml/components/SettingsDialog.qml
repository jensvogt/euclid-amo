import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Where the gateway is, who is signed in, and where the dashboards are kept.
//
// Deliberately thin: this application has one job and almost nothing to configure. The gateway
// address is here rather than only in the login dialog because a wall left running is exactly the
// thing that has to be pointed at a different installation without restarting it.
Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: 460
    padding: 24
    standardButtons: Dialog.NoButton

    property string userName: ""
    property string dashboardDirectory: ""

    signal signOutRequested()

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    onOpened: {
        hostField.text = appSettings.host
        portField.text = String(appSettings.port)
    }

    contentItem: Column {
        width: root.availableWidth
        spacing: 16

        Text {
            text: "Settings"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        Row {
            width: parent.width
            spacing: 10

            Column {
                width: (parent.width - 10) * 0.65
                spacing: 3
                Text { text: "Gateway host"; color: Theme.textFaint; font.pixelSize: 10 }
                TextField {
                    id: hostField
                    width: parent.width
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onEditingFinished: appSettings.setHost(text)
                }
            }

            Column {
                width: (parent.width - 10) * 0.35
                spacing: 3
                Text { text: "Port"; color: Theme.textFaint; font.pixelSize: 10 }
                TextField {
                    id: portField
                    width: parent.width
                    validator: IntValidator { bottom: 1; top: 65535 }
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onEditingFinished: appSettings.setPort(parseInt(text))
                }
            }
        }

        Column {
            width: parent.width
            spacing: 3
            Text { text: "Dashboards are kept in"; color: Theme.textFaint; font.pixelSize: 10 }
            Text {
                width: parent.width
                text: root.dashboardDirectory
                color: Theme.textMuted
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
        }

        Column {
            width: parent.width
            spacing: 3
            Text { text: "Signed in as"; color: Theme.textFaint; font.pixelSize: 10 }
            Text {
                text: root.userName.length > 0 ? root.userName : "(not signed in)"
                color: Theme.textMuted
                font.pixelSize: 12
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.textFaint
            font.pixelSize: 10
            text: "euclid-amo " + appVersion + " · Qt " + qtVersion + " · built " + buildDate
        }

        Item {
            width: parent.width
            height: 36

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Sign out"
                color: signOutArea.containsMouse ? Theme.bad : Theme.textMuted
                font.pixelSize: 12
                MouseArea {
                    id: signOutArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close()
                        root.signOutRequested()
                    }
                }
            }

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
