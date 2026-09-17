import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "components"

// euclid-amo: a wall of panels over the euclid monitoring module.
//
// The shape of the thing: a dashboard is a list of panels, each a query plus how to draw it. This
// window owns the list, asks EMO for one panel's data at a time, and hands the answers to the grid
// by panel id. Nothing here knows how a line or a bar is drawn, and nothing in a panel knows where
// its numbers came from.
//
// Every panel is fetched separately rather than in one query for the whole wall. EMO's "list"
// filters by one metric name, so a wall of eight panels is eight requests either way - and one
// slow or failing panel then reports its own error rather than emptying the dashboard.
ApplicationWindow {
    id: window

    // Opened in the middle of the screen it lands on, at the size below unless that screen is
    // smaller - a window wider than the display is one whose right-hand panels cannot be reached.
    //
    // Screen.width and Screen.virtualX are this screen's own geometry and its origin in the
    // virtual desktop, which is what "the current display" means here. Screen.desktopAvailableWidth
    // is the whole virtual desktop rather than one screen, and centring in that would put the
    // window over the seam between two monitors.
    readonly property int preferredWidth: 1600
    readonly property int preferredHeight: 980

    width: Screen.width > 0 ? Math.min(window.preferredWidth, Screen.width) : window.preferredWidth
    height: Screen.height > 0 ? Math.min(window.preferredHeight, Screen.height) : window.preferredHeight
    x: Screen.virtualX + (Screen.width - window.width) / 2
    y: Screen.virtualY + (Screen.height - window.height) / 2
    visible: true
    title: "Euclid AMO " + appVersion + (window.dashboard.name ? " · " + window.dashboard.name : "")
    color: Theme.background

    Material.theme: Material.Dark
    Material.accent: Theme.accent

    property bool loggedIn: false
    property string currentUser: ""
    property string currentNamespace: ""

    // The dashboard being shown, as it will be written to disk.
    property var dashboard: dashboardStore.emptyDashboard("Overview")
    // {panelId: {series, latest, minimum, maximum, total, loading, error}}
    property var panelData: ({})
    property bool editing: false
    property string lastUpdated: "—"
    property int outstanding: 0
    property var catalog: []

    readonly property var panels: window.dashboard.panels || []

    // ── Dashboard handling ───────────────────────────────────────────────────

    function openDashboard(name) {
        const loaded = dashboardStore.load(name)
        if (Object.keys(loaded).length === 0) return
        window.dashboard = loaded
        window.panelData = ({})
        window.refresh()
    }

    function persist() {
        // Saved on every change rather than behind a button. A wall is edited by dragging things
        // around, and a drag that has to be confirmed afterwards is a drag somebody will lose.
        if (!dashboardStore.save(window.dashboard.name, window.dashboard)) {
            window.showNotice(dashboardStore.lastError())
        }
    }

    // Every edit to the dashboard goes through here, and here hands back a new object rather than
    // the one it was given. A "var" property notifies when it is assigned something different, and
    // for an object "different" means a different object - so mutating this one and assigning it
    // back is a change nothing can see: no dashboardChanged, and so no redraw and no refetch.
    function updateDashboard(changes) {
        window.dashboard = Object.assign({}, window.dashboard, changes)
        window.persist()
    }

    // QML cannot see a mutation inside an array either, only an assignment - so every edit below
    // rebuilds the list. Cheap at this size, and the alternative is a wall that only redraws when
    // something else happens to change.
    function replacePanel(panelId, updated) {
        const panels = []
        for (const panel of window.panels) panels.push(panel.id === panelId ? updated : panel)
        window.updateDashboard({panels: panels})
    }

    function addPanel(panel) {
        const slot = grid.firstFreeSlot(panel.w || 8, panel.h || 6)
        panel.id = "p" + Date.now() + Math.floor(Math.random() * 1000)
        panel.x = slot.x
        panel.y = slot.y
        panel.w = panel.w || 8
        panel.h = panel.h || 6

        window.updateDashboard({panels: window.panels.concat([panel])})
        window.fetchPanel(panel)
    }

    function removePanel(panelId) {
        const panels = []
        for (const panel of window.panels) {
            if (panel.id !== panelId) panels.push(panel)
        }
        window.updateDashboard({panels: panels})
    }

    // The dashboard's own settings, as the dashboard dialog hands them back.
    //
    // A rename is a new file and then the old one gone, in that order and never the other way: the
    // name is the file name, so losing the old file before the new one is written would lose the
    // dashboard itself. If the write fails there is nothing to clean up and the old one is still
    // the dashboard.
    function applyDashboardSettings(name, range, refreshSeconds) {
        const previousName = window.dashboard.name
        const dashboard = Object.assign({}, window.dashboard,
                                        {name: name, range: range, refreshSeconds: refreshSeconds})

        if (!dashboardStore.save(name, dashboard)) {
            window.showNotice(dashboardStore.lastError())
            return
        }
        if (name !== previousName && !dashboardStore.remove(previousName)) {
            // The dashboard is safe either way - it is the new file now - so this is a stray file
            // to mention rather than a failure to undo.
            window.showNotice(dashboardStore.lastError())
        }

        window.dashboard = dashboard
        window.refresh()
    }

    function removeDashboard(name) {
        if (!dashboardStore.remove(name)) {
            window.showNotice(dashboardStore.lastError())
            return
        }

        window.panelData = ({})
        // Whatever is left, or the starter wall again - the alternative is a window showing a
        // dashboard that is no longer on disk, which the next edit would write back.
        if (dashboardStore.names.length > 0) {
            window.openDashboard(dashboardStore.names[0])
        } else {
            window.dashboard = dashboardStore.starterDashboard()
            window.persist()
            window.refresh()
        }
    }

    function panelById(panelId) {
        for (const panel of window.panels) {
            if (panel.id === panelId) return panel
        }
        return null
    }

    // ── Fetching ─────────────────────────────────────────────────────────────

    // The window a panel asks for, as an ISO instant. Relative rather than absolute: a wall left
    // running for a week should show the last hour all week, not the hour it was opened in.
    function fromIso() {
        const seconds = topBar.currentRange.seconds
        return new Date(Date.now() - seconds * 1000).toISOString()
    }

    function setPanelState(panelId, state) {
        const data = window.panelData
        data[panelId] = Object.assign({}, data[panelId] || {}, state)
        // Reassigned, not mutated - see replacePanel().
        window.panelData = ({})
        window.panelData = data
    }

    function fetchPanel(panel) {
        if (!window.loggedIn || !panel.metric) return
        window.outstanding++
        window.setPanelState(panel.id, {loading: true})
        emoClient.fetchSeries(panel.id, panel.metric, panel.labels || ({}), panel.groupBy || "",
                              window.fromIso(), "", topBar.currentRange.resolution, 1000)
    }

    function refresh() {
        if (!window.loggedIn) return
        for (const panel of window.panels) window.fetchPanel(panel)
        if (window.panels.length === 0) window.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm:ss")
    }

    function showNotice(text) {
        notice.text = text
        notice.visible = text.length > 0
        noticeTimer.restart()
    }

    Component.onCompleted: {
        // The geometry above is where to open, not a rule to keep enforcing. Assigning each of the
        // four back to itself drops its binding, so resizing the window does not re-centre it and
        // dragging it onto another monitor does not make it jump to the middle of that one.
        const opened = Qt.rect(window.x, window.y, window.width, window.height)
        window.x = opened.x
        window.y = opened.y
        window.width = opened.width
        window.height = opened.height

        if (cliUser.length > 0 && cliPassword.length > 0)
            loginDialog.autoLogin(cliUser, cliPassword, cliNamespace)
        else
            loginDialog.open()
    }

    onLoggedInChanged: {
        if (!window.loggedIn) return

        const known = dashboardStore.names

        // A name that matches nothing is said out loud rather than ignored. --dashboard exists so
        // a wall can be restarted onto the right dashboard unattended, and a wall that quietly
        // opened a different one would be a wall showing the wrong thing to whoever walks past.
        if (cliDashboard.length > 0 && known.indexOf(cliDashboard) < 0) {
            window.showNotice("No dashboard called \"" + cliDashboard + "\""
                              + (known.length > 0 ? " - opening " + known[0] + " instead." : "."))
        }

        const preferred = (cliDashboard.length > 0 && known.indexOf(cliDashboard) >= 0) ? cliDashboard
                          : (known.length > 0 ? known[0] : "")

        // A first run has no dashboards at all, and an empty grid with an "add panel" button is a
        // poor first impression of a monitoring application. The starter wall is built from the
        // metrics EMO records about itself, which are the ones certain to be there.
        //
        // Only when there are none, though: it is called "Overview" and saving it is how a first
        // run gets one, so reaching here with dashboards on disk - which a mistyped --dashboard
        // used to do - would write it straight over the Overview somebody already had.
        if (preferred.length > 0) {
            window.openDashboard(preferred)
        } else {
            window.dashboard = dashboardStore.starterDashboard()
            window.persist()
        }

        emoClient.fetchCatalog(2000)
        window.refresh()
    }

    Connections {
        target: emoClient

        function onSeriesLoaded(panelId, series, latest, minimum, maximum, total) {
            window.setPanelState(panelId, {
                series: series, latest: latest, minimum: minimum, maximum: maximum, total: total,
                loading: false, error: ""
            })
            window.outstanding = Math.max(0, window.outstanding - 1)
            window.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm:ss")
        }

        function onSeriesFailed(panelId, message) {
            window.setPanelState(panelId, {loading: false, error: message})
            window.outstanding = Math.max(0, window.outstanding - 1)
        }

        function onCatalogLoaded(metrics) {
            window.catalog = metrics
        }

        function onCatalogFailed(message) {
            // Not shown as a panel error: the catalog only feeds the editor's pickers, and a metric
            // name can be typed. Said once, quietly.
            window.showNotice("Metric list unavailable: " + message)
        }
    }

    Connections {
        target: euclidClient
        function onSessionCleared() {
            window.loggedIn = false
            window.currentUser = ""
            window.panelData = ({})
        }
    }

    Timer {
        interval: Math.max(5, window.dashboard.refreshSeconds || 30) * 1000
        running: window.loggedIn && (window.dashboard.refreshSeconds || 0) > 0
        repeat: true
        onTriggered: window.refresh()
    }

    Shortcut {
        sequences: [StandardKey.Refresh]
        onActivated: window.refresh()
    }

    // ── Layout ───────────────────────────────────────────────────────────────

    TimeRangeBar {
        id: topBar
        width: parent.width
        anchors.top: parent.top
        range: window.dashboard.range || "1h"
        refreshSeconds: window.dashboard.refreshSeconds || 30
        editing: window.editing
        dashboardName: window.dashboard.name || ""
        dashboardNames: dashboardStore.names
        lastUpdated: window.lastUpdated
        busy: window.outstanding > 0

        onRangeSelected: (label) => {
            window.updateDashboard({range: label})
            // Refetched rather than redrawn: the range is a resolution as much as a window, so the
            // points already on the wall are not the points the new range asks for.
            window.refresh()
        }
        onRefreshSelected: (seconds) => window.updateDashboard({refreshSeconds: seconds})
        onRefreshRequested: window.refresh()
        onEditingToggled: window.editing = !window.editing
        onAddPanelRequested: panelEditor.openFor({type: "line", unit: "", decimals: 0, w: 8, h: 6}, true)
        onDashboardSelected: (name) => window.openDashboard(name)
        onNewDashboardRequested: newDashboardDialog.open()
        onEditDashboardRequested: dashboardDialog.openFor(window.dashboard)
        onSettingsRequested: settingsDialog.open()
    }

    Rectangle {
        id: topBarRule
        anchors.top: topBar.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    Flickable {
        id: wall
        anchors.top: topBarRule.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: grid.contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {}

        DashboardGrid {
            id: grid
            width: wall.width
            panels: window.panels
            dataById: window.panelData
            editing: window.editing

            onPanelGeometryChanged: (panelId, x, y, w, h) => {
                const panel = window.panelById(panelId)
                if (!panel) return
                panel.x = x
                panel.y = y
                panel.w = w
                panel.h = h
                window.replacePanel(panelId, panel)
            }
            onPanelEditRequested: (panelId) => panelEditor.openFor(window.panelById(panelId), false)
            onPanelRemoveRequested: (panelId) => window.removePanel(panelId)
            onPanelDuplicateRequested: (panelId) => {
                const original = window.panelById(panelId)
                if (!original) return
                const copy = JSON.parse(JSON.stringify(original))
                copy.title = original.title + " (copy)"
                window.addPanel(copy)
            }
        }
    }

    // What an empty wall says. Not an error - a dashboard with nothing on it is a dashboard
    // somebody is about to build.
    Column {
        anchors.centerIn: wall
        width: 360
        spacing: 10
        visible: window.loggedIn && window.panels.length === 0

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing on this dashboard yet"
            color: Theme.textMuted
            font.pixelSize: 15
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Unlock the wall with the padlock, then use ＋ to place a panel."
            color: Theme.textFaint
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: notice
        property alias text: noticeText.text

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 16
        width: noticeText.implicitWidth + 24
        height: 32
        radius: 8
        color: Theme.panelHeader
        border.color: Theme.border
        border.width: 1
        visible: false

        Text {
            id: noticeText
            anchors.centerIn: parent
            color: Theme.textMuted
            font.pixelSize: 11
        }

        Timer {
            id: noticeTimer
            interval: 6000
            onTriggered: notice.visible = false
        }
    }

    PanelEditor {
        id: panelEditor
        catalog: window.catalog
        onPanelSaved: (panel) => {
            if (panelEditor.isNew) window.addPanel(panel)
            else {
                window.replacePanel(panel.id, panel)
                window.fetchPanel(panel)
            }
        }
    }

    DashboardDialog {
        id: dashboardDialog
        dashboardName: window.dashboard.name || ""
        range: window.dashboard.range || "1h"
        refreshSeconds: window.dashboard.refreshSeconds || 0
        panelCount: window.panels.length
        existingNames: dashboardStore.names
        // The two tables live on the bar that has always owned them.
        ranges: topBar.ranges
        refreshOptions: topBar.refreshOptions

        onDashboardSaved: (name, range, refreshSeconds) => window.applyDashboardSettings(name, range, refreshSeconds)
        onDashboardRemoved: (name) => window.removeDashboard(name)
    }

    SettingsDialog {
        id: settingsDialog
        userName: window.currentUser
        dashboardDirectory: dashboardStore.directory()
        onSignOutRequested: {
            euclidClient.logout()
            loginDialog.open()
        }
    }

    Dialog {
        id: newDashboardDialog
        modal: true
        anchors.centerIn: parent
        width: 380
        padding: 24
        standardButtons: Dialog.NoButton

        background: Rectangle {
            radius: 14
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        onOpened: nameField.text = ""

        contentItem: Column {
            width: newDashboardDialog.availableWidth
            spacing: 14

            Text {
                text: "New dashboard"
                color: Theme.text
                font.pixelSize: 16
                font.bold: true
            }

            TextField {
                id: nameField
                width: parent.width
                placeholderText: "Name"
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onAccepted: createButton.clicked()
            }

            Item {
                width: parent.width
                height: 34

                Button {
                    id: createButton
                    anchors.right: parent.right
                    text: "Create"
                    highlighted: true
                    enabled: nameField.text.trim().length > 0
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onClicked: {
                        const created = dashboardStore.emptyDashboard(nameField.text.trim())
                        if (!dashboardStore.save(created.name, created)) {
                            window.showNotice(dashboardStore.lastError())
                            return
                        }
                        newDashboardDialog.close()
                        window.editing = true
                        window.openDashboard(created.name)
                    }
                }
            }
        }
    }

    LoginDialog {
        id: loginDialog
        signedIn: window.loggedIn
        onLoggedIn: (username, namespaceName) => {
            window.loggedIn = true
            window.currentUser = username
            window.currentNamespace = namespaceName
            euclidClient.setNamespace(namespaceName)
        }
    }
}
