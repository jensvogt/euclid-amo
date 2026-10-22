import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Load from EMO: the configurations this user has stored, and which of the dashboards inside the
// chosen one to bring back.
//
// A list rather than a name to type: the point of storing a wall on the server is to open it on a
// machine that has never had it, which is exactly the machine whose owner cannot be expected to
// remember what it was called.
//
// Opened empty and filled when the answer arrives, rather than fetched first and opened after.
// A round trip to a gateway is long enough to look like a menu that did nothing, and a dialog that
// is already on screen saying "Loading…" is the difference between a slow answer and no answer.
// What is *inside* a configuration is fetched the same way, when one is selected: the list only
// carries names and times, and the dashboards stay on the server until somebody looks at one.
Dialog {
    id: root

    // [{name, created, modified}], as EMO listed them - most recently modified first.
    property var items: []
    property bool loading: false
    property string error: ""
    property string userId: ""

    // The configuration being looked at, and what came back when it was read.
    property string openedName: ""
    property bool loadingContents: false
    property string contentsError: ""
    // [{name, panelCount, exists}] for the check list, and the dashboards themselves - which are
    // kept here rather than fetched again when Load is pressed.
    property var contents: []

    // The names already on this machine, so a row can say what it would replace.
    property var localNames: []

    signal contentsRequested(string name)
    signal loadRequested(string name, var dashboards)

    modal: true
    anchors.centerIn: parent
    width: 520
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
        root.clearContents()
        root.open()
    }

    function clearContents() {
        root.openedName = ""
        root.contents = []
        root.contentsError = ""
        root.loadingContents = false
        checkList.setNames([], [])
    }

    function showItems(items) {
        root.items = items
        root.loading = false
        // Straight into the first one: it is the most recently saved, which is what somebody who
        // saved a wall ten minutes ago on another machine has come here for.
        if (items.length > 0) root.selectConfiguration(0)
    }

    function showError(message) {
        root.error = message
        root.loading = false
    }

    function selectConfiguration(index) {
        const chosen = root.items[index]
        if (!chosen) return
        list.currentIndex = index
        root.clearContents()
        root.openedName = chosen.name
        root.loadingContents = true
        root.contentsRequested(chosen.name)
    }

    // `dashboards` is the configuration's dashboards, whole, in the order they were saved.
    function showContents(name, dashboards) {
        // An answer for a configuration that is no longer the selected one is a slow reply to a
        // click somebody has moved on from, and showing it would put another configuration's
        // dashboards under this one's name.
        if (name !== root.openedName) return
        root.contents = dashboards
        root.loadingContents = false

        const names = dashboards.map(dashboard => dashboard.name)
        const notes = {}
        for (const dashboard of dashboards) {
            const panels = (dashboard.panels || []).length
            notes[dashboard.name] = panels + (panels === 1 ? " panel" : " panels")
                    + (root.localNames.indexOf(dashboard.name) >= 0 ? "  ·  replaces" : "")
        }
        // All of them ticked: a configuration is a wall somebody saved together, and bringing back
        // part of it is the exception.
        checkList.setNames(names, names, notes)
    }

    function showContentsError(name, message) {
        if (name !== root.openedName) return
        root.contentsError = message
        root.loadingContents = false
    }

    function formatInstant(iso) {
        const date = new Date(iso)
        return isNaN(date.getTime()) ? "—" : Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
    }

    readonly property int replacedCount: checkList.selectedNames.filter(
                                             name => root.localNames.indexOf(name) >= 0).length

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
            height: Math.min(200, Math.max(40, root.items.length * 40))
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
                        onClicked: root.selectConfiguration(row.index)
                        // The shortcut every list of things to open has.
                        onDoubleClicked: {
                            root.selectConfiguration(row.index)
                            if (loadButton.enabled) loadButton.clicked()
                        }
                    }
                }
            }
        }

        // What is in the one selected above.
        Column {
            width: parent.width
            spacing: 6
            visible: root.openedName.length > 0

            Text {
                width: parent.width
                text: "Dashboards in \"" + root.openedName + "\""
                color: Theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.loadingContents
                text: "Reading…"
                color: Theme.textMuted
                font.pixelSize: 12
            }

            Text {
                width: parent.width
                visible: !root.loadingContents && root.contentsError.length > 0
                text: root.contentsError
                color: Theme.warn
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            DashboardCheckList {
                id: checkList
                width: parent.width
                visible: !root.loadingContents && root.contentsError.length === 0
                listHeight: 160
                emptyText: "This configuration holds no dashboards."
            }

            Text {
                width: parent.width
                visible: root.replacedCount > 0
                wrapMode: Text.WordWrap
                color: Theme.warn
                font.pixelSize: 11
                // Said before the button rather than after the fact: the local file is overwritten,
                // and the dashboard that was there is gone.
                text: root.replacedCount === 1
                      ? "One of these replaces a dashboard of the same name on this machine."
                      : root.replacedCount + " of these replace dashboards of the same name on this machine."
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
                id: loadButton
                text: "Load"
                highlighted: true
                enabled: !root.loading && !root.loadingContents && checkList.selectedNames.length > 0
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    const chosen = checkList.selectedNames
                    const dashboards = root.contents.filter(dashboard => chosen.indexOf(dashboard.name) >= 0)
                    if (dashboards.length === 0) return
                    const name = root.openedName
                    root.close()
                    root.loadRequested(name, dashboards)
                }
            }
        }
    }
}
