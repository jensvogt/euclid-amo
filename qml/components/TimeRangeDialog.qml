import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Two fixed moments, instead of the six durations on the bar.
//
// Typed or picked, because the two are wanted at different moments: a timestamp copied out of a
// log goes straight into the field, while "some evening last week" is quicker to point at. The
// calendar button beside each field opens DateTimePicker, which is built out of MonthGrid and two
// Tumblers - Qt has no date-time picker of its own to drop in.
//
// Local time throughout, because that is the clock the question was asked in. What leaves here is
// UTC, because that is what EMO stores and what the panels ask for.
Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: 460
    padding: 24
    standardButtons: Dialog.NoButton

    // The format both fields are read and written in. Minutes, not seconds: EMO's finest tier is
    // a five-minute bucket, so a range to the second is a precision the data does not have.
    readonly property string format: "yyyy-MM-dd HH:mm"

    // Set by openFor(), so the dialog can say what tier the window it is describing will read.
    property string resolutionHint: ""

    signal rangeChosen(string fromIso, string toIso)

    function parseField(text) {
        // Date.fromLocaleString rather than new Date(): the latter reads an unadorned
        // "2026-10-16 14:30" differently depending on the engine, and silently.
        const parsed = Date.fromLocaleString(Qt.locale(), text.trim(), root.format)
        return isNaN(parsed.getTime()) ? null : parsed
    }

    readonly property var fromDate: root.parseField(fromField.text)
    readonly property var toDate: root.parseField(toField.text)

    readonly property bool fromValid: root.fromDate !== null
    readonly property bool toValid: root.toDate !== null
    readonly property bool orderValid: root.fromValid && root.toValid
                                       && root.toDate.getTime() > root.fromDate.getTime()
    readonly property bool usable: root.orderValid

    readonly property real spanSeconds: root.orderValid
                                        ? (root.toDate.getTime() - root.fromDate.getTime()) / 1000 : 0

    // Which field the picker is filling in. One picker serves both, because only one of them is
    // ever being answered.
    property var pickingFor: null

    function pick(field) {
        root.pickingFor = field
        picker.openFor(root.parseField(field.text) || new Date())
    }

    DateTimePicker {
        id: picker
        anchors.centerIn: parent
        onAccepted: (chosen) => {
            if (root.pickingFor) root.pickingFor.text = Qt.formatDateTime(chosen, root.format)
        }
    }

    component CalendarButton: Rectangle {
        id: calendarButton
        signal activated()

        width: 34
        height: 40
        radius: 6
        color: calendarArea.containsMouse ? Theme.panelHeader : "transparent"
        border.color: Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "▦"
            color: Theme.textMuted
            font.pixelSize: 14
        }

        ToolTip.visible: calendarArea.containsMouse
        ToolTip.text: "Pick a date and time"
        ToolTip.delay: 500

        MouseArea {
            id: calendarArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarButton.activated()
        }
    }

    function openFor(fromIso, toIso) {
        // Whatever the panels are showing now, so that opening this is a starting point rather
        // than a blank form: a custom range already set comes back, and the relative range the
        // wall is on becomes the first guess at one.
        const from = new Date(fromIso)
        const to = new Date(toIso)
        fromField.text = isNaN(from.getTime()) ? "" : Qt.formatDateTime(from, root.format)
        toField.text = isNaN(to.getTime()) ? "" : Qt.formatDateTime(to, root.format)
        root.open()
        fromField.forceActiveFocus()
        fromField.selectAll()
    }

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
            text: "Custom range"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 14
            rowSpacing: 10

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "From"; color: Theme.textFaint; font.pixelSize: 10 }
                Row {
                    width: parent.width
                    spacing: 6

                    TextField {
                        id: fromField
                        width: parent.width - fromCalendar.width - 6
                        placeholderText: root.format
                        Material.theme: Material.Dark
                        Material.accent: root.fromValid ? Theme.accent : Theme.bad
                        onAccepted: if (root.usable) applyButton.clicked()
                    }

                    CalendarButton {
                        id: fromCalendar
                        anchors.verticalCenter: parent.verticalCenter
                        onActivated: root.pick(fromField)
                    }
                }
            }

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "To"; color: Theme.textFaint; font.pixelSize: 10 }
                Row {
                    width: parent.width
                    spacing: 6

                    TextField {
                        id: toField
                        width: parent.width - toCalendar.width - 6
                        placeholderText: root.format
                        Material.theme: Material.Dark
                        Material.accent: root.toValid ? Theme.accent : Theme.bad
                        onAccepted: if (root.usable) applyButton.clicked()
                    }

                    CalendarButton {
                        id: toCalendar
                        anchors.verticalCenter: parent.verticalCenter
                        onActivated: root.pick(toField)
                    }
                }
            }
        }

        // What the two fields add up to, or what is wrong with them. One line that is always
        // there, so the dialog does not change height as it is typed into.
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: 10
            color: root.usable ? Theme.textFaint : Theme.bad
            text: {
                if (!root.fromValid || !root.toValid) return "Both ends are read as " + root.format + "."
                if (!root.orderValid) return "The end has to come after the start."
                const hours = root.spanSeconds / 3600
                const span = hours >= 48 ? (hours / 24).toFixed(1) + " days"
                           : hours >= 1 ? hours.toFixed(1) + " hours"
                           : Math.round(root.spanSeconds / 60) + " minutes"
                return span + ", read from the " + root.resolutionHint + " tier."
            }
        }

        Item {
            width: parent.width
            height: 36

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Cancel"
                color: cancelArea.containsMouse ? Theme.text : Theme.textMuted
                font.pixelSize: 12
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
                id: applyButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Apply"
                highlighted: true
                enabled: root.usable
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    root.rangeChosen(root.fromDate.toISOString(), root.toDate.toISOString())
                    root.close()
                }
            }
        }
    }
}
