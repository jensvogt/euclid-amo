import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Choosing a metric out of a list that is long and made of long names.
//
// A dropdown was the obvious control and the wrong one: ninety-odd names, most of them a prefix
// and four words joined by underscores, in a field half the width of a dialog. The names that
// differ only at the end - ..._parsed_xml_files_count against ..._failed_xml_files_count - are
// exactly the ones an elided list cannot tell apart.
//
// So: full width for the names, a search that matches anywhere in them, and the prefixes as
// chips, because these names are already grouped that way by whoever pushed them ("system-",
// "module-", "pim_import_onix3_") and picking the group first cuts ninety down to a handful.
Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: Math.min(840, (parent ? parent.width : 900) - 80)
    height: Math.min(600, (parent ? parent.height : 700) - 80)
    padding: 20
    standardButtons: Dialog.NoButton

    // [{name, labelKeys, labelValues}], as EmoClient assembles it.
    property var catalog: []
    // The name the editor already had, highlighted when the dialog opens.
    property string current: ""

    signal metricChosen(string name)

    // The part of a name before its first separator. Both conventions are in the data at once -
    // euclid's own metrics use dashes, everything pushed by an application seems to use
    // underscores - so both count as one.
    function prefixOf(name) {
        const at = name.search(/[-_.]/)
        return at > 0 ? name.substring(0, at) : name
    }

    readonly property var prefixes: {
        const counts = ({})
        for (const metric of root.catalog) {
            const prefix = root.prefixOf(metric.name)
            counts[prefix] = (counts[prefix] || 0) + 1
        }
        const out = []
        for (const prefix of Object.keys(counts).sort()) out.push({name: prefix, count: counts[prefix]})
        return out
    }

    property string activePrefix: ""

    readonly property var matches: {
        const needle = searchField.text.trim().toLowerCase()
        const out = []
        for (const metric of root.catalog) {
            if (root.activePrefix.length > 0 && root.prefixOf(metric.name) !== root.activePrefix) continue
            if (needle.length > 0 && metric.name.toLowerCase().indexOf(needle) < 0) continue
            out.push(metric)
        }
        return out
    }

    // Whether what has been typed is already a name in the list. When it is not, the footer offers
    // to use it anyway - a metric that has not been written recently enough to be in the catalog is
    // still a metric worth charting, and refusing to accept its name would make the application
    // useless for exactly the series somebody is investigating: the one that stopped.
    readonly property bool typedIsKnown: {
        const typed = searchField.text.trim()
        if (typed.length === 0) return true
        for (const metric of root.catalog) {
            if (metric.name === typed) return true
        }
        return false
    }

    function openFor(metricName, metricCatalog) {
        root.catalog = metricCatalog || []
        root.current = metricName || ""
        root.activePrefix = ""
        searchField.text = ""
        root.open()
        // Selecting the row the editor already holds, so the dialog opens showing where it is in
        // the list rather than at the top of it.
        for (let i = 0; i < root.matches.length; ++i) {
            if (root.matches[i].name === root.current) {
                metricList.currentIndex = i
                metricList.positionViewAtIndex(i, ListView.Center)
                break
            }
        }
        searchField.forceActiveFocus()
    }

    function choose(name) {
        if (name.length === 0) return
        root.metricChosen(name)
        root.close()
    }

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    contentItem: Item {

        Text {
            id: heading
            anchors.top: parent.top
            text: "Choose a metric"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        TextField {
            id: searchField
            anchors.top: heading.bottom
            anchors.topMargin: 12
            width: parent.width
            placeholderText: "Filter - matches anywhere in the name"
            Material.theme: Material.Dark
            Material.accent: Theme.accent

            // The list is driven from here rather than focused itself: typing should keep narrowing
            // the list, and the arrow keys should still walk it.
            Keys.onDownPressed: metricList.incrementCurrentIndex()
            Keys.onUpPressed: metricList.decrementCurrentIndex()
            onAccepted: {
                if (metricList.currentIndex >= 0 && metricList.currentIndex < root.matches.length)
                    root.choose(root.matches[metricList.currentIndex].name)
                else if (!root.typedIsKnown)
                    root.choose(searchField.text.trim())
            }
            onTextChanged: metricList.currentIndex = root.matches.length > 0 ? 0 : -1
        }

        // The prefixes, wrapped rather than scrolled. A single row would need twice this width for
        // twenty-odd of them, and a row that scrolls sideways with nothing to say so hides the
        // prefixes at the end of the alphabet completely - which on this data is "system".
        Flow {
            id: prefixBar
            anchors.top: searchField.bottom
            anchors.topMargin: 12
            width: parent.width
            spacing: 6

            PrefixChip {
                label: "All"
                count: root.catalog.length
                active: root.activePrefix.length === 0
                onPicked: root.activePrefix = ""
            }

            Repeater {
                model: root.prefixes
                delegate: PrefixChip {
                    required property var modelData
                    label: modelData.name
                    count: modelData.count
                    active: root.activePrefix === modelData.name
                    // Clicking the active one clears it, so the way back to all of them is the
                    // chip already under the pointer rather than a trip to "All".
                    onPicked: root.activePrefix = root.activePrefix === modelData.name ? "" : modelData.name
                }
            }
        }

        Rectangle {
            id: listFrame
            anchors.top: prefixBar.bottom
            anchors.topMargin: 12
            anchors.bottom: footer.top
            anchors.bottomMargin: 12
            width: parent.width
            color: Theme.background
            radius: 8
            border.color: Theme.border
            border.width: 1

            ListView {
                id: metricList
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: root.matches
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index

                    width: metricList.width
                    height: 44
                    color: metricList.currentIndex === row.index ? Theme.panelHeader
                           : (rowArea.containsMouse ? Theme.grid : "transparent")

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.modelData.name
                            color: row.modelData.name === root.current ? Theme.accent : Theme.text
                            font.pixelSize: 13
                            // The one place a name is not elided if it can be helped: this is the
                            // width the dialog exists to give it.
                            elide: Text.ElideMiddle
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.labelKeys.length > 0
                                  ? "dimensions: " + row.modelData.labelKeys.join(", ")
                                  : "no dimensions"
                            color: Theme.textFaint
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            metricList.currentIndex = row.index
                            root.choose(row.modelData.name)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.matches.length === 0
                text: root.catalog.length === 0
                      ? "No metrics known yet - EMO has not answered, or has nothing stored."
                      : "Nothing matches. The name can still be used: a metric quiet for long "
                        + "enough to fall out of the catalog is not a metric that stopped existing."
                color: Theme.textFaint
                font.pixelSize: 11
            }
        }

        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            height: 34

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.matches.length + " of " + root.catalog.length
                color: Theme.textFaint
                font.pixelSize: 11
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

                // Not highlighted, although it is the only button here: picking a row is the
                // ordinary way out of this dialog, and a primary-looking button that appears the
                // moment somebody starts typing a filter would suggest otherwise.
                Button {
                    text: "Use \"" + searchField.text.trim() + "\""
                    visible: !root.typedIsKnown
                    flat: true
                    anchors.verticalCenter: parent.verticalCenter
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onClicked: root.choose(searchField.text.trim())
                }
            }
        }
    }

    component PrefixChip: Rectangle {
        id: chip
        property string label: ""
        property int count: 0
        property bool active: false
        signal picked()

        width: chipText.implicitWidth + 20
        height: 26
        radius: 13
        color: chip.active ? Theme.accent : (chipArea.containsMouse ? Theme.panelHeader : "transparent")
        border.color: chip.active ? Theme.accent : Theme.border
        border.width: 1

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label + " " + chip.count
            color: chip.active ? "white" : Theme.textMuted
            font.pixelSize: 11
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.picked()
        }
    }
}
