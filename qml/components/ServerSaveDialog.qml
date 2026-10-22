import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Save to EMO: a name to save under, and which of the dashboards on this machine go into it.
//
// What gets stored is a *configuration* - one entry in EMO holding any number of dashboards -
// rather than one entry per dashboard. That is what makes this worth a dialog: the thing somebody
// wants on the other machine is usually the wall they have built, all of it, under one name they
// can remember.
//
// The list of what is already saved is fetched while the dialog is open, for one reason only: to
// say when the name being typed would replace something. It is not needed to save, so the dialog
// works whether or not that answer ever arrives.
Dialog {
    id: root

    // Every dashboard on this machine, and the one on screen - which is the one ticked to begin
    // with, since saving what you are looking at is the common case.
    property var localNames: []
    property string currentName: ""

    // [{name, created, modified}] as EMO listed them, for the overwrite line.
    property var savedItems: []
    property bool loadingList: false
    property string listError: ""
    property bool saving: false

    readonly property var savedNames: root.savedItems.map(item => item.name)
    readonly property string typedName: nameField.text.trim()
    readonly property bool replacesExisting: root.savedNames.indexOf(root.typedName) >= 0

    signal saveRequested(string name, var dashboardNames)

    modal: true
    anchors.centerIn: parent
    width: 480
    padding: 24
    standardButtons: Dialog.NoButton

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    function beginFor(names, current) {
        root.localNames = names
        root.currentName = current
        root.savedItems = []
        root.listError = ""
        root.loadingList = true
        root.saving = false
        root.open()
    }

    function showItems(items) {
        root.savedItems = items
        root.loadingList = false
        // The combo follows the field: a name already in the field that turns out to be one of
        // these shows as the configuration it would replace, rather than as "New configuration"
        // beside a warning saying the opposite.
        existingCombo.currentIndex = root.savedNames.indexOf(root.typedName) + 1
    }

    function showError(message) {
        // Not shown as a failure: nothing here needs the list, and a gateway that cannot answer it
        // must not be the reason somebody cannot save. It only costs the overwrite warning.
        root.listError = message
        root.loadingList = false
    }

    function formatInstant(iso) {
        const date = new Date(iso)
        return isNaN(date.getTime()) ? "—" : Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
    }

    function savedEntry(name) {
        for (const item of root.savedItems) {
            if (item.name === name) return item
        }
        return null
    }

    onOpened: {
        // Prefilled with the dashboard on screen and selected, so that saving just this one is
        // still one keystroke away - and typing over it is how a configuration gets a name of its
        // own. Nothing rewrites this afterwards: the list of saved names arrives while somebody is
        // typing here, and a field that changed under them would be the editor bug all over again.
        nameField.text = root.currentName
        checkList.setNames(root.localNames, [root.currentName])
        nameField.selectAll()
        nameField.forceActiveFocus()
    }

    contentItem: Column {
        width: root.availableWidth
        spacing: 14

        Text {
            text: "Save to EMO"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        Column {
            id: nameColumn
            width: parent.width
            spacing: 6

            Text { text: "Save over an existing configuration"; color: Theme.textMuted; font.pixelSize: 12 }

            // The ones already in EMO, to save over one of them without having to remember and
            // retype its name - which on the machine this exists for is a name somebody has never
            // typed. Picking one fills the field below; the field is still where the name comes
            // from, so a new one is just typed there instead.
            ComboBox {
                id: existingCombo
                width: parent.width
                enabled: !root.loadingList && root.savedItems.length > 0
                font.pixelSize: 13
                Material.theme: Material.Dark
                Material.accent: Theme.accent

                // The placeholder first, so the combo opens on "not one of these" rather than on
                // whichever configuration happens to have been saved last - which would read as an
                // offer to overwrite it.
                model: [root.loadingList
                        ? "Reading what is already saved…"
                        : (root.savedItems.length > 0 ? "New configuration" : "Nothing saved yet")]
                       .concat(root.savedNames)

                // currentIndex is assigned rather than bound, here and in nameField below: a
                // ComboBox resets it when its model is replaced, and the list arrives while this
                // dialog is open - so a binding would be overwritten moments after it was set.
                // showItems() does the assigning, once the names are in.
                onActivated: (index) => {
                    if (index <= 0) return
                    nameField.text = root.savedNames[index - 1]
                }
            }

            Text {
                text: "Name"
                color: Theme.textMuted
                font.pixelSize: 12
                topPadding: 6
            }

            TextField {
                id: nameField
                width: parent.width
                placeholderText: "e.g. Production wall"
                color: Theme.text
                font.pixelSize: 13
                selectByMouse: true
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                Keys.onReturnPressed: if (saveButton.enabled) saveButton.clicked()
                // Typing a name that is one of the saved ones selects it above, so the two never
                // disagree about which configuration is about to be written.
                onTextEdited: existingCombo.currentIndex = root.savedNames.indexOf(text.trim()) + 1
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                visible: text.length > 0
                color: root.replacesExisting ? Theme.warn : Theme.textFaint
                text: {
                    if (root.loadingList) return "Reading what is already saved…"
                    if (!root.replacesExisting) return root.listError.length > 0
                                                      ? "Could not read what is already saved: " + root.listError
                                                      : "Saved under the signed-in user, and opened from any machine they sign in on."
                    const existing = root.savedEntry(root.typedName)
                    return "Replaces the configuration saved under this name"
                           + (existing ? " on " + root.formatInstant(existing.modified) : "") + "."
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6

            Text { text: "Dashboards to include"; color: Theme.textMuted; font.pixelSize: 12 }

            DashboardCheckList {
                id: checkList
                width: parent.width
                emptyText: "There are no dashboards on this machine to save."
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
                id: saveButton
                text: "Save"
                highlighted: true
                enabled: !root.saving && root.typedName.length > 0 && checkList.selectedNames.length > 0
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    root.saving = true
                    root.close()
                    root.saveRequested(root.typedName, checkList.selectedNames)
                }
            }
        }
    }
}
