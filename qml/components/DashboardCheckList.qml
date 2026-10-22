import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// A list of dashboards with a box beside each, and one box above that takes all of them. Shared by
// the two EMO dialogs: saving picks which of the dashboards on this machine go into a configuration,
// loading picks which of the ones in a configuration come back out, and neither is a different
// question.
//
// The entries are a plain array of {name, checked, note} that is *replaced* on every toggle rather
// than edited in place. A "var" property notifies when it is assigned something different, and for
// an array that means a different array - so ticking a box by mutating the one already there would
// change nothing anybody can see.
Column {
    id: root

    // [{name, checked, note}] - note is the grey line on the right, for whatever the dialog using
    // this has to say about a row ("replaces the one here", "4 panels").
    property var entries: []
    property string allText: "All dashboards"
    property string emptyText: "Nothing to choose from."
    property int listHeight: 180

    readonly property var selectedNames: root.entries.filter(entry => entry.checked).map(entry => entry.name)
    readonly property bool allChecked: root.entries.length > 0
                                       && root.selectedNames.length === root.entries.length

    // Builds the list from names, ticking the ones named in `checked`.
    function setNames(names, checked, notes) {
        const built = []
        for (const name of names) {
            built.push({
                name: name,
                checked: checked ? checked.indexOf(name) >= 0 : false,
                note: notes && notes[name] !== undefined ? notes[name] : ""
            })
        }
        root.entries = built
    }

    function setAll(on) {
        root.entries = root.entries.map(entry => ({name: entry.name, checked: on, note: entry.note}))
    }

    function toggle(index) {
        root.entries = root.entries.map(function (entry, at) {
            return at === index ? {name: entry.name, checked: !entry.checked, note: entry.note} : entry
        })
    }

    spacing: 8

    CheckBox {
        id: allBox
        text: root.allText
        font.pixelSize: 12
        enabled: root.entries.length > 0
        checked: root.allChecked
        Material.theme: Material.Dark
        Material.accent: Theme.accent
        // onToggled, not onCheckedChanged: the box follows the rows below it, so the binding above
        // moves it whenever they change - and reacting to that would turn "one row unticked" into
        // "every row unticked".
        onToggled: root.setAll(checked)
    }

    Text {
        width: parent.width
        visible: root.entries.length === 0
        text: root.emptyText
        color: Theme.textMuted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: Math.min(root.listHeight, Math.max(32, root.entries.length * 32))
        visible: root.entries.length > 0
        radius: 8
        color: Theme.background
        border.color: Theme.border
        border.width: 1
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 1
            model: root.entries
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: row
                required property var modelData
                required property int index

                width: list.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                }

                CheckBox {
                    id: box
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    font.pixelSize: 12
                    checked: row.modelData.checked
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onToggled: root.toggle(row.index)
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.note
                    color: Theme.textFaint
                    font.pixelSize: 11
                }

                // The whole row, not just the box: a list of things to tick is one somebody clicks
                // along rather than aims at.
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    // Behind the CheckBox so its own click still reaches it, rather than being
                    // swallowed here and toggled twice.
                    z: -1
                    onClicked: root.toggle(row.index)
                }
            }
        }
    }
}
