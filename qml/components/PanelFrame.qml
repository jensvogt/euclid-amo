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
    // Something worth knowing about a chart that still drew. Unlike "error" this does not replace
    // the content - the line is there and readable, it just is not the line it appears to be.
    property string warning: ""
    // What the panel is for, in the words of whoever built it. A metric name and a title say what
    // is being drawn; this is the part a reader cannot work out from the chart - where the number
    // comes from, what counts as normal, what to do when it is not. Empty on most panels, and the
    // mark that opens it is absent when it is.
    property string description: ""
    property bool editing: false
    // Set by clicking the mark: the description then stays up with the pointer elsewhere, which is
    // what reading more than a line needs.
    property bool descriptionPinned: false
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

        // What is left for the title once the right-hand furniture has had its share: the three
        // edit buttons when the wall is unlocked, and the description mark whenever there is one.
        // Measured rather than assumed, so a title no longer runs under the ⓘ on a locked wall.
        readonly property real textWidth: Math.max(0, width - 24
                                                   - (panelActions.visible ? panelActions.width + 10 : 0)
                                                   - (infoMark.visible ? infoMark.width + 10 : 0))

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
                width: header.textWidth
            }
            Text {
                text: root.subtitle
                color: Theme.textFaint
                font.pixelSize: 10
                visible: root.subtitle.length > 0 && header.height > 30
                elide: Text.ElideRight
                width: header.textWidth
            }
        }

        BusyIndicator {
            anchors.right: infoMark.visible ? infoMark.left : panelActions.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            running: root.loading
            visible: root.loading
        }

        // The upper-right corner, and visible whether or not the wall is unlocked - unlike the
        // three buttons beside it, reading a panel is not editing it.
        Text {
            id: infoMark
            anchors.right: panelActions.visible ? panelActions.left : parent.right
            anchors.rightMargin: panelActions.visible ? 10 : 10
            anchors.verticalCenter: parent.verticalCenter
            visible: root.description.length > 0
            text: "ⓘ"
            font.pixelSize: 13
            color: infoArea.containsMouse || root.descriptionPinned ? Theme.accent : Theme.textMuted

            MouseArea {
                id: infoArea
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hovering shows it, clicking keeps it: a sentence is read on the way past, three
                // are read with the pointer somewhere else.
                onEntered: descriptionPopup.open()
                onExited: if (!root.descriptionPinned) descriptionPopup.close()
                onClicked: {
                    root.descriptionPinned = !root.descriptionPinned
                    if (root.descriptionPinned) descriptionPopup.open()
                    else descriptionPopup.close()
                }
            }
        }

        // A popup rather than a ToolTip, because a tooltip does not wrap: Qt sizes one to its text
        // and a description three sentences long becomes a line wider than the window. This one
        // has a width, so it reads as a paragraph.
        Popup {
            id: descriptionPopup
            parent: root
            // A column wide enough to read, whatever the panel is: a small gauge is three columns
            // of the grid, and a paragraph set to that width is a word a line. It hangs over the
            // neighbours instead - it is an overlay, and it is gone as soon as the pointer leaves.
            width: Math.min(320, root.Window.width > 0 ? root.Window.width - 24 : 320)

            // Right-aligned under the mark, then pushed back inside the window: the panel this is
            // parented to can be anywhere on the wall, and the ones at the edges are exactly the
            // ones a popup wider than its panel would hang off the screen.
            x: {
                const preferred = infoMark.x + infoMark.width - width
                const sceneX = root.mapToItem(null, 0, 0).x
                const windowWidth = root.Window.width > 0 ? root.Window.width : sceneX + root.width
                return Math.max(8 - sceneX, Math.min(preferred, windowWidth - sceneX - width - 8))
            }
            // Under the mark where there is room, above it where there is not: a panel low on
            // the wall would otherwise open a paragraph that runs off the bottom of the window,
            // and the end of a description is the part nobody can scroll to.
            y: {
                const below = header.height + 2
                const sceneY = root.mapToItem(null, 0, 0).y
                const windowHeight = root.Window.height > 0 ? root.Window.height : sceneY + root.height
                if (sceneY + below + height <= windowHeight - 8) return below
                const above = -height - 2
                if (sceneY + above >= 8) return above
                // Taller than the window has room for either way: sit as low as it can.
                return Math.max(8 - sceneY, windowHeight - sceneY - height - 8)
            }
            padding: 10
            // Hover and the pin drive this between them; an auto-close would fight the click that
            // pins it. Escape still works, and unpins on the way out.
            closePolicy: Popup.CloseOnEscape
            onClosed: root.descriptionPinned = false

            background: Rectangle {
                radius: 8
                color: Theme.panelHeader
                border.color: Theme.border
                border.width: 1
            }

            contentItem: Text {
                text: root.description
                color: Theme.text
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
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

    // Along the bottom edge, over the chart rather than beside it: a panel is as small as its owner
    // made it, and taking a strip of height away from the drawing to explain the drawing would
    // leave some panels with neither.
    Rectangle {
        id: warningStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: 22
        radius: 6
        color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.12)
        visible: root.warning.length > 0 && root.error.length === 0

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: "⚠"
                color: Theme.warn
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                width: parent.width - 20
                text: root.warning
                color: Theme.textMuted
                font.pixelSize: 10
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ToolTip.visible: warningArea.containsMouse
        ToolTip.text: root.warning
        ToolTip.delay: 300

        MouseArea {
            id: warningArea
            anchors.fill: parent
            hoverEnabled: true
        }
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
