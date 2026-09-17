import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// What a panel shows, and how.
//
// The metric name is a field that can be typed into as well as picked from MetricPicker, and that
// is deliberate: the catalog is assembled by reading what EMO has stored rather than asked for
// (see EmoClient::fetchCatalog), so a metric quiet for long enough can be missing from it.
// Refusing to chart what the picker cannot offer would make the application useless for exactly
// the series somebody is investigating - the one that stopped.
Dialog {
    id: root
    modal: true
    anchors.centerIn: parent
    width: 560
    padding: 24
    standardButtons: Dialog.NoButton

    // The catalog, as EmoClient answers it: [{name, labelKeys, labelValues}].
    property var catalog: []
    // The panel being edited, or an empty map for a new one.
    property var panel: ({})
    property bool isNew: false
    // Which dimension of the panel's label map the one filter row is showing, so that saving
    // replaces that one rather than the whole map. Empty when the panel had no filter.
    property string loadedFilterKey: ""

    // Not "accepted": Dialog has a signal of that name already, and a second one is an
    // invalid override rather than an addition.
    signal panelSaved(var panel)

    readonly property var currentMetric: {
        for (const metric of root.catalog) {
            if (metric.name === metricField.text) return metric
        }
        return null
    }

    function openFor(existing, creating) {
        root.panel = existing ? JSON.parse(JSON.stringify(existing)) : ({})
        root.isNew = creating === true
        titleField.text = root.panel.title || ""
        metricField.text = root.panel.metric || ""
        typeBox.currentIndex = Math.max(0, typeBox.model.indexOf(root.panel.type || "line"))
        unitBox.currentIndex = Math.max(0, unitBox.model.indexOf(root.panel.unit || ""))
        reduceBox.currentIndex = Math.max(0, reduceBox.model.indexOf(root.panel.reduce || "latest"))
        decimalsBox.value = root.panel.decimals || 0
        groupByField.editText = root.panel.groupBy || ""

        // The filter the panel already carries, put back into the form. It used to be cleared here
        // whatever the panel held, which made the filter look like it had not been saved - and then
        // made that true, because the next save wrote this empty form back over it.
        //
        // One pair, out of a map that can hold several: the form has one row, so the first pair is
        // the one it shows and the key it loaded is remembered for the save below.
        const labels = root.panel.labels || ({})
        const filterKeys = Object.keys(labels)
        root.loadedFilterKey = filterKeys.length > 0 ? filterKeys[0] : ""
        filterKeyField.editText = root.loadedFilterKey
        filterValueField.editText = root.loadedFilterKey.length > 0 ? labels[root.loadedFilterKey] : ""

        root.open()
    }

    background: Rectangle {
        radius: 14
        color: Theme.panel
        border.color: Theme.border
        border.width: 1
    }

    // Parented to the window's overlay rather than to this dialog, so it is centred on and sized
    // against the window: the picker is deliberately wider than the editor that opens it.
    MetricPicker {
        id: metricPicker
        parent: Overlay.overlay
        onMetricChosen: (name) => metricField.text = name
    }

    contentItem: Column {
        width: root.availableWidth
        spacing: 14

        Text {
            text: root.isNew ? "Add panel" : "Edit panel"
            color: Theme.text
            font.pixelSize: 16
            font.bold: true
        }

        // Outside the Grid and across the whole dialog, because it is the one field whose value is
        // long: a metric name is a prefix and several words, and at half the width the names that
        // differ only at the end read identically. Everything else here fits in half.
        Column {
            width: parent.width
            spacing: 3

            Text { text: "Metric"; color: Theme.textFaint; font.pixelSize: 10 }

            Row {
                width: parent.width
                spacing: 8

                TextField {
                    id: metricField
                    width: parent.width - browseButton.width - 8
                    // No placeholder, unlike the other fields: Material floats one up onto the
                    // border as soon as there is text, and this field almost always has some -
                    // which would print a second label directly under the one above.
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    // Typed as well as picked, deliberately - see the note at the top of the file.
                    // The picker is the comfortable way in, not the only one.
                    ToolTip.visible: hovered && metricField.text.length > 0
                    ToolTip.text: metricField.text
                    ToolTip.delay: 600
                }

                Button {
                    id: browseButton
                    text: "Browse…"
                    anchors.verticalCenter: parent.verticalCenter
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                    onClicked: metricPicker.openFor(metricField.text, root.catalog)
                }
            }
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 14
            rowSpacing: 10

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Title"; color: Theme.textFaint; font.pixelSize: 10 }
                TextField {
                    id: titleField
                    width: parent.width
                    placeholderText: "Shown in the panel header"
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Visualisation"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: typeBox
                    width: parent.width
                    model: ["line", "bar", "stat", "gauge"]
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            // Every cell here is half the dialog, and has to be: a Grid sizes a column to its
            // widest item, so one full-width cell in the left column would push the right one -
            // visualisation, split, the filter value - off the edge of the dialog entirely.
            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text {
                    text: "Split by dimension"
                    color: Theme.textFaint
                    font.pixelSize: 10
                }
                ComboBox {
                    id: groupByField
                    width: parent.width
                    editable: true
                    // The dimensions this metric has actually been seen with, which is the only
                    // place they exist: EMO stores a label map per row and declares nothing.
                    model: {
                        const keys = [""]
                        if (root.currentMetric) {
                            for (const key of root.currentMetric.labelKeys) keys.push(key)
                        }
                        return keys
                    }
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Unit"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: unitBox
                    width: parent.width
                    model: MetricFormat.units
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Filter dimension"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: filterKeyField
                    width: parent.width
                    editable: true
                    model: {
                        const keys = [""]
                        if (root.currentMetric) {
                            for (const key of root.currentMetric.labelKeys) keys.push(key)
                        }
                        return keys
                    }
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "equals"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: filterValueField
                    width: parent.width
                    editable: true
                    model: {
                        if (!root.currentMetric || !filterKeyField.editText) return [""]
                        const values = root.currentMetric.labelValues[filterKeyField.editText]
                        return values ? [""].concat(values) : [""]
                    }
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            // Moved down from beside Unit so that the filter and its value stay on one row: with
            // the metric lifted out of the Grid the cells no longer pair the way they did.
            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Decimals"; color: Theme.textFaint; font.pixelSize: 10 }
                SpinBox {
                    id: decimalsBox
                    width: parent.width
                    from: 0
                    to: 4
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

            // Last of the cells, and the only one that comes and goes: a Grid closes the gap left
            // by an invisible child by shifting everything after it up, so anywhere earlier this
            // would break the pairs above - the filter and its value most of all - every time the
            // visualisation changed.
            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                visible: typeBox.currentText === "stat" || typeBox.currentText === "bar"
                Text { text: "Value over range"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: reduceBox
                    width: parent.width
                    // The stored words rather than prettier ones: they are what a dashboard file
                    // carries and what BarChart already reads, and one vocabulary across the two
                    // panel types is worth more than one nicer label. "total" is the sum of every
                    // value in the window.
                    model: ["latest", "max", "total"]
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }
        }

        // Why the two dimension pickers are empty, when they are. Without this the answer looks
        // like a broken dialog rather than what it is: EMO stores a label map per row and declares
        // nothing, so a dimension exists here only once something has pushed the metric carrying
        // it - and a metric that stopped being written before its application started tagging has
        // none at all.
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.warn
            font.pixelSize: 10
            visible: metricField.text.length > 0
                     && (!root.currentMetric || root.currentMetric.labelKeys.length === 0)
            text: root.currentMetric
                  ? "No dimensions have been recorded for this metric, so there is nothing to split "
                    + "or filter by. One appears here as soon as the metric is pushed carrying it."
                  : "This metric is not in the catalog, so its dimensions are unknown. A name can "
                    + "still be typed into either field above."
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.textFaint
            font.pixelSize: 10
            text: "A filter narrows to one dimension value; splitting draws a line per value of a "
                  + "dimension. Leave both empty to chart everything stored under the metric as one series."
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
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.isNew ? "Add panel" : "Save panel"
                highlighted: true
                enabled: metricField.text.length > 0
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    const edited = root.panel
                    edited.title = titleField.text.length > 0 ? titleField.text : metricField.text
                    edited.type = typeBox.currentText
                    edited.metric = metricField.text
                    edited.groupBy = groupByField.editText
                    edited.unit = unitBox.currentText
                    edited.decimals = decimalsBox.value
                    // Written whatever the type is, so that a panel switched to a line and back
                    // finds the figure it was showing still chosen.
                    edited.reduce = reduceBox.currentText
                    // Built from what the panel already had rather than from the form alone: this
                    // dialog edits one dimension, and a dashboard hand-written to filter on two
                    // should not lose the second one by being opened here. The row's own dimension
                    // is dropped first, so clearing the form clears the filter.
                    const labels = ({})
                    const existingLabels = root.panel.labels || ({})
                    for (const key of Object.keys(existingLabels)) {
                        if (key !== root.loadedFilterKey) labels[key] = existingLabels[key]
                    }
                    if (filterKeyField.editText.length > 0 && filterValueField.editText.length > 0) {
                        labels[filterKeyField.editText] = filterValueField.editText
                    }
                    edited.labels = labels
                    root.panelSaved(edited)
                    root.close()
                }
            }
        }
    }
}
