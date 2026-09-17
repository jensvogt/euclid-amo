import QtQuick

// One number, large enough to read across a room, with the shape of where it has been behind it.
//
// The sparkline is not decoration: a stat without one answers "what is it now" and nothing else,
// and the question somebody walking up to a wall actually has is "is that normal". Drawn without
// axes or labels deliberately - it is a shape, and anything more would compete with the number.
Item {
    id: root

    property real value: 0
    property var points: []
    property string unit: ""
    property int decimals: 0
    property color accent: Theme.accent
    // Optional bounds that colour the number: a value past "warnAbove" is amber, past "badAbove"
    // red. Left unset, the number is simply the accent colour.
    property real warnAbove: NaN
    property real badAbove: NaN

    readonly property color valueColor: {
        if (!isNaN(root.badAbove) && root.value >= root.badAbove) return Theme.bad
        if (!isNaN(root.warnAbove) && root.value >= root.warnAbove) return Theme.warn
        return root.accent
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 2

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: MetricFormat.format(root.value, root.unit, root.decimals)
            color: root.valueColor
            // Scaled to the panel rather than fixed: the same stat is readable in a 4x3 tile and
            // fills a 12x6 one, which is what makes a panel worth resizing.
            font.pixelSize: Math.max(18, Math.min(root.height * 0.38, root.width * 0.22))
            font.bold: true
            elide: Text.ElideRight
        }
    }

    Canvas {
        id: spark
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(48, root.height * 0.3)
        visible: root.points.length > 1
        opacity: 0.55

        onPaint: {
            const context = getContext("2d")
            context.reset()
            if (root.points.length < 2) return

            let minimum = Number.POSITIVE_INFINITY
            let maximum = Number.NEGATIVE_INFINITY
            for (const point of root.points) {
                minimum = Math.min(minimum, point.value)
                maximum = Math.max(maximum, point.value)
            }
            // A flat line sits in the middle rather than at the bottom: a constant is not a zero.
            const span = maximum - minimum
            const scale = span > 0 ? span : 1
            const base = span > 0 ? minimum : minimum - 0.5

            context.beginPath()
            for (let i = 0; i < root.points.length; ++i) {
                const x = width * i / (root.points.length - 1)
                const y = height - 4 - (height - 8) * (root.points[i].value - base) / scale
                if (i === 0) context.moveTo(x, y)
                else context.lineTo(x, y)
            }
            context.strokeStyle = root.accent
            context.lineWidth = 2
            context.stroke()

            context.lineTo(width, height)
            context.lineTo(0, height)
            context.closePath()
            context.fillStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
            context.fill()
        }
    }

    onPointsChanged: spark.requestPaint()
    onAccentChanged: spark.requestPaint()
}
