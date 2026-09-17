import QtQuick

// The wall: panels placed on a 24-column grid, moved and resized by dragging.
//
// 24 columns because that is what Grafana uses and the arithmetic is the reason rather than the
// precedent: 24 divides by 2, 3, 4, 6, 8 and 12, so halves, thirds and quarters of a row all land
// on whole columns. A 12-column grid cannot express a third of a row without a remainder.
//
// Height is in rows of a fixed pixel height rather than a fraction of the viewport. A dashboard is
// read on whatever screen it is put on, and panels that grow with the window would make a wall
// designed on a laptop unreadable on a television - where the useful behaviour is more panels
// visible at the same size, which is what a fixed row height and a scrolling canvas give.
Item {
    id: root

    // [{id, title, type, metric, labels, groupBy, unit, decimals, x, y, w, h}], in no particular
    // order - the grid coordinates place them, not their position in the list.
    property var panels: []
    // {panelId: {series, latest, minimum, maximum, total, loading, error}}
    property var dataById: ({})
    // Locked, a panel cannot be moved, resized or removed and its header carries no buttons.
    property bool editing: false

    property int columns: 24
    property int rowHeight: 40
    property int gutter: 10

    readonly property real cellWidth: (width - gutter) / columns
    // The wall is as tall as the lowest panel reaches, plus a row of air to drop something into.
    readonly property real contentHeight: {
        let bottom = 0
        for (const panel of root.panels) bottom = Math.max(bottom, (panel.y + panel.h))
        return (bottom + 2) * (rowHeight + gutter) + gutter
    }

    // A panel was moved or resized: the caller writes it back into its own model and saves.
    signal panelGeometryChanged(string panelId, int x, int y, int w, int h)
    signal panelEditRequested(string panelId)
    signal panelRemoveRequested(string panelId)
    signal panelDuplicateRequested(string panelId)

    implicitHeight: contentHeight

    function pixelX(column) { return gutter + column * cellWidth }
    function pixelY(row) { return gutter + row * (rowHeight + gutter) }
    function pixelWidth(span) { return span * cellWidth - gutter }
    function pixelHeight(span) { return span * (rowHeight + gutter) - gutter }

    function columnAt(x) { return Math.round((x - gutter) / cellWidth) }
    function rowAt(y) { return Math.round((y - gutter) / (rowHeight + gutter)) }

    // Whether a rectangle in grid units is free, ignoring the panel being moved. Overlap is
    // rejected rather than resolved by pushing the neighbours around: a wall where dropping one
    // panel rearranges three others is a wall somebody has to repair afterwards, and a refusal is
    // both easier to understand and easier to undo.
    function isFree(panelId, x, y, w, h) {
        if (x < 0 || y < 0 || x + w > root.columns) return false
        for (const panel of root.panels) {
            if (panel.id === panelId) continue
            if (x < panel.x + panel.w && x + w > panel.x && y < panel.y + panel.h && y + h > panel.y)
                return false
        }
        return true
    }

    // Where a new panel fits: the first free spot scanning left to right, top to bottom. Bounded
    // rather than unbounded so a wall that is somehow full still answers - at the bottom, which is
    // where a panel that could not be placed anywhere else belongs.
    function firstFreeSlot(w, h) {
        for (let y = 0; y < 200; ++y) {
            for (let x = 0; x + w <= root.columns; ++x) {
                if (isFree("", x, y, w, h)) return {x: x, y: y}
            }
        }
        return {x: 0, y: 200}
    }

    Repeater {
        model: root.panels

        delegate: Item {
            id: cell
            required property var modelData

            readonly property var panelData: root.dataById[cell.modelData.id] || ({})
            // While a gesture is in progress the item is positioned by the drag rather than by the
            // model, so both bindings have to stand aside - reasserting either mid-drag would snap
            // the panel back under the pointer's feet.
            property bool dragging: false
            property bool resizing: false
            property bool rejected: false

            x: cell.dragging ? x : root.pixelX(cell.modelData.x)
            y: cell.dragging ? y : root.pixelY(cell.modelData.y)
            width: cell.resizing ? width : root.pixelWidth(cell.modelData.w)
            height: cell.resizing ? height : root.pixelHeight(cell.modelData.h)
            z: cell.dragging || cell.resizing ? 10 : 1

            Behavior on x { enabled: !cell.dragging; NumberAnimation { duration: 120 } }
            Behavior on y { enabled: !cell.dragging; NumberAnimation { duration: 120 } }

            PanelFrame {
                id: frame
                anchors.fill: parent
                title: cell.modelData.title
                subtitle: cell.modelData.metric + (cell.modelData.groupBy ? " · by " + cell.modelData.groupBy : "")
                loading: cell.panelData.loading === true
                error: cell.panelData.error || ""
                editing: root.editing
                active: cell.dragging || cell.resizing
                border.color: cell.rejected ? Theme.bad
                              : (cell.dragging || cell.resizing ? Theme.borderActive : Theme.border)

                onEditRequested: root.panelEditRequested(cell.modelData.id)
                onRemoveRequested: root.panelRemoveRequested(cell.modelData.id)
                onDuplicateRequested: root.panelDuplicateRequested(cell.modelData.id)

                Loader {
                    anchors.fill: parent
                    sourceComponent: {
                        switch (cell.modelData.type) {
                        case "stat": return statComponent
                        case "gauge": return gaugeComponent
                        case "bar": return barComponent
                        default: return lineComponent
                        }
                    }
                }
            }

            Component {
                id: lineComponent
                LineChart {
                    // The chart takes {name, color, points}; the colour is assigned here so that
                    // the legend, the bars and the sparklines all draw the same series the same.
                    series: {
                        const source = cell.panelData.series || []
                        const out = []
                        for (let i = 0; i < source.length; ++i) {
                            out.push({name: source[i].name, color: Theme.seriesColor(i), points: source[i].points})
                        }
                        return out
                    }
                    // The panel's unit, whatever it is. It used to be "%" or nothing, which left
                    // every other unit - bytes above all - drawn as a bare number.
                    unit: cell.modelData.unit || ""
                    decimals: cell.modelData.decimals || 0
                    timeFormat: root.editing ? "hh:mm" : "hh:mm"
                }
            }

            Component {
                id: barComponent
                BarChart {
                    series: cell.panelData.series || []
                    unit: cell.modelData.unit || ""
                    decimals: cell.modelData.decimals || 0
                    reduce: cell.modelData.reduce || "latest"
                }
            }

            Component {
                id: statComponent
                StatPanel {
                    // Which figure over the window the number is, in the vocabulary BarChart
                    // already uses. Chosen here rather than inside StatPanel because EmoClient has
                    // derived all three already, over every row the query returned - so a metric
                    // split into several series totals to the sum of the bars a bar panel would
                    // draw for it, rather than to whichever series happened to come first.
                    value: {
                        switch (cell.modelData.reduce) {
                        case "total": return cell.panelData.total || 0
                        case "max": return cell.panelData.maximum || 0
                        default: return cell.panelData.latest || 0
                        }
                    }
                    points: (cell.panelData.series && cell.panelData.series.length > 0)
                            ? cell.panelData.series[0].points : []
                    unit: cell.modelData.unit || ""
                    decimals: cell.modelData.decimals || 0
                }
            }

            Component {
                id: gaugeComponent
                GaugePanel {
                    value: cell.panelData.latest || 0
                    minimum: cell.modelData.minimum !== undefined ? cell.modelData.minimum : 0
                    maximum: cell.modelData.maximum !== undefined ? cell.modelData.maximum : 100
                    unit: cell.modelData.unit || "%"
                    decimals: cell.modelData.decimals || 0
                }
            }

            // Moving. The header strip is the handle rather than the whole panel, so that a chart
            // keeps its own hover, crosshair and zoom while the wall is unlocked.
            //
            // Underneath the frame, because this covers the header's own edit, duplicate and remove
            // buttons - which appear on exactly the same condition that enables this, so on top it
            // would swallow every click any of them ever got. The header itself accepts no mouse
            // events, so a press that misses a button falls through to here and still drags.
            MouseArea {
                z: -1
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34
                enabled: root.editing
                cursorShape: enabled ? (cell.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                drag.target: cell
                drag.axis: Drag.XAndYAxis
                // Not drag.minimum/maximum: the panel may be dragged past the right edge on its way
                // somewhere, and it is the drop that has to land inside the grid, not every frame
                // of the gesture.
                onPressed: cell.dragging = true
                onReleased: {
                    cell.dragging = false
                    const column = Math.max(0, Math.min(root.columns - cell.modelData.w, root.columnAt(cell.x)))
                    const row = Math.max(0, root.rowAt(cell.y))
                    if (root.isFree(cell.modelData.id, column, row, cell.modelData.w, cell.modelData.h)) {
                        root.panelGeometryChanged(cell.modelData.id, column, row, cell.modelData.w, cell.modelData.h)
                    } else {
                        // Rejected: the bindings above take the panel home by themselves as soon as
                        // "dragging" goes false, and the border says why for a moment.
                        cell.rejected = true
                        rejectedTimer.restart()
                    }
                    cell.x = root.pixelX(cell.modelData.x)
                    cell.y = root.pixelY(cell.modelData.y)
                }
            }

            // Resizing, from the corner every window in every toolkit resizes from.
            MouseArea {
                id: grip
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                enabled: root.editing
                cursorShape: enabled ? Qt.SizeFDiagCursor : Qt.ArrowCursor

                property real startX: 0
                property real startY: 0
                property real startWidth: 0
                property real startHeight: 0

                onPressed: mouse => {
                    cell.resizing = true
                    grip.startX = mouse.x
                    grip.startY = mouse.y
                    grip.startWidth = cell.width
                    grip.startHeight = cell.height
                }
                onPositionChanged: mouse => {
                    if (!cell.resizing) return
                    cell.width = Math.max(root.cellWidth * 2, grip.startWidth + (mouse.x - grip.startX))
                    cell.height = Math.max(root.rowHeight * 2, grip.startHeight + (mouse.y - grip.startY))
                }
                onReleased: {
                    cell.resizing = false
                    const w = Math.max(2, Math.min(root.columns - cell.modelData.x,
                                                   Math.round((cell.width + root.gutter) / root.cellWidth)))
                    const h = Math.max(2, Math.round((cell.height + root.gutter) / (root.rowHeight + root.gutter)))
                    if (root.isFree(cell.modelData.id, cell.modelData.x, cell.modelData.y, w, h)) {
                        root.panelGeometryChanged(cell.modelData.id, cell.modelData.x, cell.modelData.y, w, h)
                    } else {
                        cell.rejected = true
                        rejectedTimer.restart()
                    }
                    cell.width = root.pixelWidth(cell.modelData.w)
                    cell.height = root.pixelHeight(cell.modelData.h)
                }

                Canvas {
                    anchors.fill: parent
                    visible: root.editing
                    onPaint: {
                        const context = getContext("2d")
                        context.reset()
                        context.strokeStyle = Theme.textFaint
                        context.lineWidth = 1
                        for (let offset = 4; offset <= 12; offset += 4) {
                            context.beginPath()
                            context.moveTo(width - offset, height - 2)
                            context.lineTo(width - 2, height - offset)
                            context.stroke()
                        }
                    }
                }
            }

            Timer {
                id: rejectedTimer
                interval: 600
                onTriggered: cell.rejected = false
            }
        }
    }
}
