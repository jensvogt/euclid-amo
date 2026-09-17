import QtQuick

// One bar per series, showing where each stands now rather than how it got there.
//
// What a bar chart is for on a monitoring wall is comparison across a dimension - which module has
// the instances, which method carries the traffic - so the bars are ordered by value rather than by
// name: the answer to "which is biggest" should be the first thing read, not something the eye has
// to search an alphabetical list for.
Item {
    id: root

    // [{name, points: [{timestamp, value}]}] - the same shape the line chart takes, so a panel can
    // be switched between the two without refetching.
    property var series: []
    property string unit: ""
    property int decimals: 0
    // Which figure of a series the bar represents. "latest" is the last sample, "max" its peak,
    // "total" the sum across the window - the last being the one that makes a RATE meaningful.
    property string reduce: "latest"

    readonly property var bars: {
        const out = []
        for (let i = 0; i < root.series.length; ++i) {
            const points = root.series[i].points || []
            if (points.length === 0) continue

            let value = points[points.length - 1].value
            if (root.reduce === "max") {
                value = Number.NEGATIVE_INFINITY
                for (const point of points) value = Math.max(value, point.value)
            } else if (root.reduce === "total") {
                value = 0
                for (const point of points) value += point.value
            }
            out.push({name: root.series[i].name, value: value, color: Theme.seriesColor(i)})
        }
        out.sort((a, b) => b.value - a.value)
        return out
    }

    readonly property real peak: {
        let maximum = 0
        for (const bar of root.bars) maximum = Math.max(maximum, Math.abs(bar.value))
        return maximum
    }

    Text {
        anchors.centerIn: parent
        visible: root.bars.length === 0
        text: "No data"
        color: Theme.textFaint
        font.pixelSize: 12
    }

    // Horizontal bars, not vertical: the labels are names of arbitrary length ("parsing-result-
    // queue", "G1 Eden Space"), and vertical bars would leave them rotated or truncated.
    Column {
        anchors.fill: parent
        spacing: Math.max(2, Math.min(8, (root.height - root.bars.length * 18) / Math.max(1, root.bars.length)))
        visible: root.bars.length > 0

        Repeater {
            model: root.bars

            delegate: Item {
                id: barRow
                required property var modelData

                width: parent.width
                height: Math.max(16, Math.min(26, (root.height / Math.max(1, root.bars.length)) - 4))

                Text {
                    id: barLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(parent.width * 0.4, 160)
                    text: barRow.modelData.name
                    color: Theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    id: track
                    anchors.left: barLabel.right
                    anchors.leftMargin: 8
                    anchors.right: barValue.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(8, parent.height * 0.55)
                    radius: 4
                    color: Theme.grid

                    Rectangle {
                        width: root.peak > 0 ? Math.max(2, track.width * Math.abs(barRow.modelData.value) / root.peak) : 0
                        height: parent.height
                        radius: 4
                        color: barRow.modelData.color
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    id: barValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: MetricFormat.format(barRow.modelData.value, root.unit, root.decimals)
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
