import QtQuick

// A row of blocks along time, one per bucket: green where the value was true, red where it was
// false, blue where nothing was recorded at all.
//
// The third colour is the reason this panel exists. A line chart of a metric that is only ever 0
// or 1 draws a square wave nobody can read at a glance, and - worse - it joins the last point
// before an outage to the first one after it, so the gap where a service was not reporting looks
// exactly like a stretch where it was reporting fine. Here "nothing arrived" is a colour of its
// own, which on a wall is the thing worth seeing from across the room.
Item {
    id: root

    // One entry per row: {name, color, points: [{"timestamp": ISO string, "value": number}]}.
    property var series: []
    property string unit: ""
    property int decimals: 0

    // The window the panel asked EMO for, so that time with no data at either end is drawn as
    // such. Without them the strip can only be as wide as the data it got, and a service that
    // stopped reporting an hour ago would look like one that is still reporting.
    property string windowFrom: ""
    property string windowTo: ""

    // Anything other than zero is true. A boolean pushed through a metric arrives as 1 or 0, but
    // "2 replicas" is as true as "1 replica" and should not read as a failure.
    function stateOf(value) { return value === 0 ? "false" : "true" }

    readonly property color trueColor: Theme.good
    readonly property color falseColor: Theme.bad
    readonly property color missingColor: Theme.accent

    readonly property real labelWidth: 54
    readonly property real axisHeight: 18
    readonly property real rowSpacing: 6

    readonly property bool hasData: root.series.some(s => s.points && s.points.length > 0)

    // Everything the painting needs, worked out once per data change rather than per frame:
    // {rows: [{name, cells: [{t, state, value}]}], tMin, tMax, step}.
    readonly property var strip: root.buildStrip()

    function buildStrip() {
        const rows = []
        let tMin = Number.POSITIVE_INFINITY
        let tMax = Number.NEGATIVE_INFINITY
        let step = 0

        for (const entry of root.series) {
            const points = []
            for (const point of (entry.points || [])) {
                const t = Date.parse(point.timestamp)
                if (isNaN(t)) continue
                points.push({t: t, value: point.value})
                tMin = Math.min(tMin, t)
                tMax = Math.max(tMax, t)
            }
            points.sort((left, right) => left.t - right.t)

            // The bucket size, taken from the data rather than from the resolution the panel was
            // fetched with: the smallest gap between two readings is the cadence they arrived at,
            // and it is the one thing here that does not need plumbing through from the top bar.
            for (let i = 1; i < points.length; ++i) {
                const gap = points[i].t - points[i - 1].t
                if (gap > 0 && (step === 0 || gap < step)) step = gap
            }
            rows.push({name: entry.name, points: points})
        }

        const windowFrom = Date.parse(root.windowFrom)
        const windowTo = Date.parse(root.windowTo)
        if (!isNaN(windowFrom)) tMin = Math.min(tMin, windowFrom)
        if (!isNaN(windowTo)) tMax = Math.max(tMax, windowTo)
        else if (tMax !== Number.NEGATIVE_INFINITY) tMax = Math.max(tMax, Date.now())

        if (tMin === Number.POSITIVE_INFINITY || tMax <= tMin) return {rows: [], tMin: 0, tMax: 0, step: 0}
        // A single reading has no gap to measure, and a window with none at all still has to be
        // divided into something: forty blocks reads as a strip rather than as one long bar.
        if (step <= 0) step = Math.max(60000, (tMax - tMin) / 40)

        const built = []
        for (const row of rows) {
            const cells = []
            // Walked bucket by bucket rather than point by point, because the buckets without a
            // point are the ones this panel is for.
            for (let t = tMin; t < tMax; t += step) {
                let found = null
                for (const point of row.points) {
                    if (Math.abs(point.t - t) <= step / 2) { found = point; break }
                    if (point.t > t + step) break
                }
                cells.push(found ? {t: t, state: root.stateOf(found.value), value: found.value}
                                 : {t: t, state: "missing", value: NaN})
            }
            built.push({name: row.name, cells: cells})
        }
        return {rows: built, tMin: tMin, tMax: tMax, step: step}
    }

    function colorFor(state) {
        return state === "true" ? root.trueColor
             : state === "false" ? root.falseColor
             : root.missingColor
    }

    onStripChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Text {
        anchors.centerIn: parent
        visible: !root.hasData
        text: "No data yet"
        color: Theme.textFaint
        font.pixelSize: 12
    }

    // The row names, as items rather than painted into the canvas: they are text at a fixed place
    // and get the font rendering every other label on the wall gets.
    Column {
        id: rowLabels
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.labelWidth
        spacing: root.rowSpacing
        visible: root.hasData

        Repeater {
            model: root.strip.rows

            delegate: Text {
                required property var modelData

                width: root.labelWidth - 8
                height: root.rowHeight
                verticalAlignment: Text.AlignVCenter
                text: modelData.name
                color: Theme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    readonly property real rowHeight: {
        const count = root.strip.rows.length
        if (count === 0) return 0
        const available = root.height - root.axisHeight - (count - 1) * root.rowSpacing
        return Math.max(12, available / count)
    }

    Canvas {
        id: canvas
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.hasData

        onPaint: {
            const context = getContext("2d")
            context.reset()

            const rows = root.strip.rows
            if (rows.length === 0 || width <= 0) return

            const span = root.strip.tMax - root.strip.tMin
            if (span <= 0) return

            const blockWidth = width * root.strip.step / span
            // A hairline between blocks while there is room for one. Below that the gaps would eat
            // the blocks, and a solid band of colour is the more honest picture anyway.
            const gap = blockWidth > 6 ? 1 : 0

            for (let r = 0; r < rows.length; ++r) {
                const top = r * (root.rowHeight + root.rowSpacing)
                for (const cell of rows[r].cells) {
                    const x = width * (cell.t - root.strip.tMin) / span
                    context.fillStyle = root.colorFor(cell.state)
                    context.fillRect(x, top, Math.max(1, blockWidth - gap), root.rowHeight)
                }

                // The value inside the block, when a block is wide enough to hold one.
                if (blockWidth >= 30 && root.rowHeight >= 18) {
                    context.fillStyle = "white"
                    context.font = "11px sans-serif"
                    context.textAlign = "center"
                    context.textBaseline = "middle"
                    for (const cell of rows[r].cells) {
                        if (cell.state === "missing") continue
                        const x = width * (cell.t - root.strip.tMin) / span
                        context.fillText(MetricFormat.format(cell.value, root.unit, root.decimals),
                                         x + (blockWidth - gap) / 2, top + root.rowHeight / 2)
                    }
                }
            }

            // The axis: a handful of times under the strip rather than one per block, which at
            // five-minute buckets would be unreadable.
            context.fillStyle = Theme.textFaint
            context.font = "10px sans-serif"
            context.textBaseline = "top"
            const ticks = Math.max(2, Math.min(8, Math.floor(width / 90)))
            for (let i = 0; i <= ticks; ++i) {
                const fraction = i / ticks
                const when = new Date(root.strip.tMin + span * fraction)
                context.textAlign = i === 0 ? "left" : i === ticks ? "right" : "center"
                context.fillText(Qt.formatDateTime(when, span > 86400000 ? "dd MMM" : "hh:mm"),
                                 width * fraction, height - root.axisHeight + 4)
            }
        }
    }

    // What is under the pointer, which on a strip of identical blocks is the only way to read one.
    HoverHandler {
        id: hover
        enabled: root.hasData
    }

    readonly property var hoveredCell: {
        if (!hover.hovered || root.strip.rows.length === 0) return null
        const x = hover.point.position.x - root.labelWidth
        const y = hover.point.position.y
        if (x < 0 || canvas.width <= 0) return null

        const row = Math.floor(y / (root.rowHeight + root.rowSpacing))
        if (row < 0 || row >= root.strip.rows.length) return null

        const span = root.strip.tMax - root.strip.tMin
        const t = root.strip.tMin + span * x / canvas.width
        const cells = root.strip.rows[row].cells
        for (const cell of cells) {
            if (t >= cell.t && t < cell.t + root.strip.step) return {row: root.strip.rows[row], cell: cell}
        }
        return null
    }

    Rectangle {
        visible: root.hoveredCell !== null
        x: Math.min(root.width - width - 4, Math.max(4, hover.point.position.x + 12))
        y: Math.max(4, hover.point.position.y - height - 8)
        width: tip.implicitWidth + 16
        height: tip.implicitHeight + 10
        radius: 6
        color: Theme.panelHeader
        border.color: Theme.border
        border.width: 1

        Text {
            id: tip
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 10
            text: {
                if (root.hoveredCell === null) return ""
                const cell = root.hoveredCell.cell
                const when = Qt.formatDateTime(new Date(cell.t), "dd MMM hh:mm")
                const what = cell.state === "missing"
                           ? "no data"
                           : MetricFormat.format(cell.value, root.unit, root.decimals)
                return root.hoveredCell.row.name + "   " + when + "   " + what
            }
        }
    }
}
