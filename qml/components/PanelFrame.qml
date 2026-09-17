import QtQuick
import QtQuick.Controls

// The box a panel lives in: its title, its state, and the two handles that move and resize it.
//
// Everything about *what* is drawn belongs to the content item passed in; this owns only the
// chrome. The split matters because the chrome is what makes the wall feel like one thing - every
// panel gets the same header, the same loading behaviour and the same error treatment, whatever it
// is showing.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool loading: false
    property string error: ""
    property bool editing: false
    // While a panel is being dragged or resized it is lifted out of the wall: a border, a shadow of
    // sorts, and it stops responding to hover so the pointer belongs to the gesture.
    property bool active: false

    default property alias content: contentArea.data

    signal editRequested()
    signal removeRequested()
    signal duplicateRequested()

    color: Theme.panel
    radius: 10
    border.color: root.active ? Theme.borderActive : Theme.border
    border.width: 1

    Rectangle {
        id: header
        width: parent.width
        height: 34
        radius: 10
        color: Theme.panelHeader

        // The radius belongs to the panel, not to the strip: without this the header's own bottom
        // corners are rounded in the middle of a flat panel.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.radius
            color: parent.color
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: root.title
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                width: Math.max(0, header.width - 110)
            }
            Text {
                text: root.subtitle
                color: Theme.textFaint
                font.pixelSize: 10
                visible: root.subtitle.length > 0 && header.height > 30
                elide: Text.ElideRight
                width: Math.max(0, header.width - 110)
            }
        }

        BusyIndicator {
            anchors.right: panelActions.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            running: root.loading
            visible: root.loading
        }

        Row {
            id: panelActions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            // Only while the wall is unlocked. A panel on a screen nobody sits at should not carry
            // a delete button one stray click away from emptying it.
            visible: root.editing

            Text {
                text: "✎"
                color: editArea.containsMouse ? Theme.accent : Theme.textMuted
                font.pixelSize: 13
                MouseArea {
                    id: editArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editRequested()
                }
            }

            Text {
                text: "⧉"
                color: copyArea.containsMouse ? Theme.accent : Theme.textMuted
                font.pixelSize: 13
                MouseArea {
                    id: copyArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.duplicateRequested()
                }
            }

            Text {
                text: "✕"
                color: closeArea.containsMouse ? Theme.bad : Theme.textMuted
                font.pixelSize: 12
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeRequested()
                }
            }
        }
    }

    Item {
        id: contentArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        clip: true
        // Hidden rather than covered, so a chart is not left half visible behind a message about
        // why it could not be drawn.
        visible: root.error.length === 0
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 6
        visible: root.error.length > 0

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "⚠"
            color: Theme.warn
            font.pixelSize: 18
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.error
            color: Theme.textMuted
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
}
