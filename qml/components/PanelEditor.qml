import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// What a panel shows, and how.
//
// The metric name is a combo box that can also be typed into, and that is deliberate: the list is
// assembled by reading what EMO has stored recently (see EmoClient::fetchCatalog), so a metric
// that exists but has been quiet is missing from it. Refusing to chart what the picker cannot
// offer would make the application useless for exactly the series somebody is investigating - the
// one that stopped.
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

    // Not "accepted": Dialog has a signal of that name already, and a second one is an
    // invalid override rather than an addition.
    signal panelSaved(var panel)

    readonly property var currentMetric: {
        for (const metric of root.catalog) {
            if (metric.name === metricField.editText) return metric
        }
        return null
    }

    function openFor(existing, creating) {
        root.panel = existing ? JSON.parse(JSON.stringify(existing)) : ({})
        root.isNew = creating === true
        titleField.text = root.panel.title || ""
        metricField.editText = root.panel.metric || ""
        typeBox.currentIndex = Math.max(0, typeBox.model.indexOf(root.panel.type || "line"))
        unitBox.currentIndex = Math.max(0, unitBox.model.indexOf(root.panel.unit || ""))
        reduceBox.currentIndex = Math.max(0, reduceBox.model.indexOf(root.panel.reduce || "latest"))
        decimalsBox.value = root.panel.decimals || 0
        groupByField.editText = root.panel.groupBy || ""
        filterKeyField.editText = ""
        filterValueField.editText = ""
        root.open()
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
            text: root.isNew ? "Add panel" : "Edit panel"
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

            // Half the width, like every other cell, because a Grid sizes a column to its widest
            // item: one full-width cell in the left column pushes the right one - visualisation,
            // split, decimals, the filter value - off the edge of the dialog entirely.
            Column {
                width: (parent.width - 14) / 2
                spacing: 3
                Text { text: "Metric"; color: Theme.textFaint; font.pixelSize: 10 }
                ComboBox {
                    id: metricField
                    width: parent.width
                    editable: true
                    model: {
                        const names = []
                        for (const metric of root.catalog) names.push(metric.name)
                        return names
                    }
                    Material.theme: Material.Dark
                    Material.accent: Theme.accent
                }
            }

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
                enabled: metricField.editText.length > 0
                Material.theme: Material.Dark
                Material.accent: Theme.accent
                onClicked: {
                    const edited = root.panel
                    edited.title = titleField.text.length > 0 ? titleField.text : metricField.editText
                    edited.type = typeBox.currentText
                    edited.metric = metricField.editText
                    edited.groupBy = groupByField.editText
                    edited.unit = unitBox.currentText
                    edited.decimals = decimalsBox.value
                    // Written whatever the type is, so that a panel switched to a line and back
                    // finds the figure it was showing still chosen.
                    edited.reduce = reduceBox.currentText
                    edited.labels = filterKeyField.editText.length > 0 && filterValueField.editText.length > 0
                            ? ({[filterKeyField.editText]: filterValueField.editText}) : ({})
                    root.panelSaved(edited)
                    root.close()
                }
            }
        }
    }
}
