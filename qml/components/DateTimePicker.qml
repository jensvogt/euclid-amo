import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
// Qualified on purpose. The calendar types are only in the Basic style - no other style draws
// them - and importing that style unqualified would also put Basic's Button and TextField in
// scope, quietly winning over the Material ones everywhere else in this file.
import QtQuick.Controls.Basic as Unstyled

// A month to point at and two wheels for the time, for the fields that otherwise have to be typed.
//
// Qt has no date-time picker to drop in - QDateTimeEdit is a widget, and Qt Quick Controls has
// never had an equivalent - but it does have the parts: MonthGrid lays out the days of a month and
// says which one was clicked, DayOfWeekRow writes the column headings in the right language, and
// Tumbler is the wheel. What is left is deciding what they should look like, which is this file.
Popup {
    id: root

    modal: true
    dim: true
    padding: 16
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Minutes move in fives because EMO's finest tier is a five-minute bucket: a wheel offering
    // sixty would be offering a precision the data behind it does not have. The field this fills
    // in still takes any minute that is typed into it.
    readonly property int minuteStep: 5

    // The day under the cursor, kept apart from the month on show so that paging back and forth
    // does not lose it.
    property date selected: new Date()
    property int shownMonth: 0
    property int shownYear: 2000

    signal accepted(date chosen)

    // Where the two wheels should come to rest, kept until the popup is actually open. A Tumbler
    // inside a closed Popup has not laid its view out yet: told to go to the tenth hour it records
    // the ten and goes on showing the seventh, so the wheel and the time underneath it disagree.
    property int pendingHour: 0
    property int pendingMinuteIndex: 0

    onOpened: {
        hourTumbler.currentIndex = root.pendingHour
        minuteTumbler.currentIndex = root.pendingMinuteIndex
    }

    function openFor(initial) {
        const start = (initial && !isNaN(initial.getTime())) ? initial : new Date()
        root.selected = new Date(start.getFullYear(), start.getMonth(), start.getDate())
        root.shownMonth = start.getMonth()
        root.shownYear = start.getFullYear()
        root.pendingHour = start.getHours()
        // Clamped rather than wrapped: rounding 58 minutes up to the twelfth step would be
        // midnight of the same day, an hour earlier than what was asked for.
        root.pendingMinuteIndex = Math.min(60 / root.minuteStep - 1,
                                           Math.round(start.getMinutes() / root.minuteStep))
        root.open()
    }

    function stepMonth(by) {
        const moved = new Date(root.shownYear, root.shownMonth + by, 1)
        root.shownMonth = moved.getMonth()
        root.shownYear = moved.getFullYear()
    }

    function isSameDay(left, right) {
        return left.getFullYear() === right.getFullYear()
               && left.getMonth() === right.getMonth()
               && left.getDate() === right.getDate()
    }

    background: Rectangle {
        radius: 12
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    contentItem: Column {
        spacing: 10

        // ── The month on show, and the way back and forth ────────────────────────────────────

        Item {
            width: parent.width
            height: 28

            PagerButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: "‹"
                onActivated: root.stepMonth(-1)
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(root.shownYear, root.shownMonth, 1), "MMMM yyyy")
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
            }

            PagerButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: "›"
                onActivated: root.stepMonth(1)
            }
        }

        Unstyled.DayOfWeekRow {
            width: parent.width
            spacing: 2
            delegate: Text {
                required property string shortName
                width: 34
                horizontalAlignment: Text.AlignHCenter
                text: shortName
                color: Theme.textFaint
                font.pixelSize: 10
            }
        }

        Unstyled.MonthGrid {
            id: grid
            width: parent.width
            month: root.shownMonth
            year: root.shownYear
            spacing: 2

            delegate: Rectangle {
                id: dayCell
                required property var model

                width: 34
                height: 30
                radius: 6
                // The days either side of the month are shown rather than hidden - a week that
                // stops halfway reads as missing data - but dimmed, and they stay clickable so a
                // range that crosses a month boundary does not need the pager.
                opacity: dayCell.model.month === root.shownMonth ? 1 : 0.35
                color: root.isSameDay(dayCell.model.date, root.selected) ? Theme.accent
                       : (dayArea.containsMouse ? Theme.panelHeader : "transparent")
                border.color: dayCell.model.today && !root.isSameDay(dayCell.model.date, root.selected)
                              ? Theme.accent : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: dayCell.model.day
                    color: root.isSameDay(dayCell.model.date, root.selected) ? "white" : Theme.text
                    font.pixelSize: 12
                }

                MouseArea {
                    id: dayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selected = dayCell.model.date
                        // Clicking into a neighbouring month brings that month forward, so the
                        // next click is where it looks like it is.
                        if (dayCell.model.month !== root.shownMonth) {
                            root.shownMonth = dayCell.model.date.getMonth()
                            root.shownYear = dayCell.model.date.getFullYear()
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // ── The time, as two wheels ──────────────────────────────────────────────────────────

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Tumbler {
                id: hourTumbler
                width: 62
                height: 96
                visibleItemCount: 3
                wrap: true
                model: 24
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                delegate: TumblerLabel {}
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                color: Theme.textMuted
                font.pixelSize: 16
            }

            Tumbler {
                id: minuteTumbler
                width: 62
                height: 96
                visibleItemCount: 3
                wrap: true
                model: 60 / root.minuteStep
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                delegate: TumblerLabel { step: root.minuteStep }
            }
        }

        // ── What it adds up to, and the way out ──────────────────────────────────────────────

        // On its own line rather than beside the button: the popup is as wide as a month of day
        // cells, which leaves no room to put a timestamp next to anything.
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(root.chosenValue, "yyyy-MM-dd HH:mm")
            color: Theme.textMuted
            font.pixelSize: 11
        }

        Item {
            width: parent.width
            height: 34

            Button {
                id: setButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Set"
                highlighted: true
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    root.accepted(root.chosenValue)
                    root.close()
                }
            }
        }
    }

    // The day under the cursor and the two wheels, as one instant.
    readonly property date chosenValue: new Date(root.selected.getFullYear(),
                                                 root.selected.getMonth(),
                                                 root.selected.getDate(),
                                                 hourTumbler.currentIndex,
                                                 minuteTumbler.currentIndex * root.minuteStep)

    component TumblerLabel: Text {
        // Both required and both needed: declaring any required property turns off the context
        // properties a delegate would otherwise be handed, so "modelData" has to be asked for by
        // name - and Tumbler's attached properties are only available to a delegate that has an
        // "index" to be attached to.
        required property int index
        required property int modelData

        // What one step of the wheel is worth. The hours wheel counts in ones, the minutes wheel
        // in fives.
        property int step: 1

        readonly property int value: modelData * step

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: value < 10 ? "0" + value : String(value)
        color: Theme.text
        font.pixelSize: 14
        // The wheel's own fade, so the rows either side of the middle read as further away.
        opacity: 1 - Math.abs(Tumbler.displacement) / 1.6
    }

    component PagerButton: Rectangle {
        id: pager
        property string label: ""
        signal activated()

        width: 26
        height: 26
        radius: 13
        color: pagerArea.containsMouse ? Theme.panelHeader : "transparent"

        Text {
            anchors.centerIn: parent
            text: pager.label
            color: Theme.textMuted
            font.pixelSize: 15
        }

        MouseArea {
            id: pagerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pager.activated()
        }
    }
}
