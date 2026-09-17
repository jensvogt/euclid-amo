import QtQuick

// A value against a range, drawn as a 240-degree arc.
//
// For the metrics that have a ceiling - a percentage, a pool against its maximum - where the
// question is "how much of it is used" rather than "what is the number". Anything without a
// meaningful maximum is a stat, not a gauge: an arc implies a full that a byte count has no answer
// for, and a gauge of unbounded values is a gauge always near its start or always pinned.
Item {
    id: root

    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property string unit: "%"
    property int decimals: 0
    property real warnAbove: 70
    property real badAbove: 90

    readonly property real fraction: {
        const span = root.maximum - root.minimum
        if (span <= 0) return 0
        return Math.max(0, Math.min(1, (root.value - root.minimum) / span))
    }

    readonly property color arcColor: {
        if (root.value >= root.badAbove) return Theme.bad
        if (root.value >= root.warnAbove) return Theme.warn
        return Theme.good
    }

    Canvas {
        id: arc
        anchors.fill: parent
        anchors.margins: 8

        onPaint: {
            const context = getContext("2d")
            context.reset()

            const centreX = width / 2
            // Low rather than centred: the arc is a 240-degree sweep with its opening at the
            // bottom, so its visual mass sits above the geometric centre.
            const centreY = height * 0.62
            const radius = Math.max(10, Math.min(width / 2, centreY) - 12)
            const thickness = Math.max(6, radius * 0.22)

            const start = Math.PI * 0.75
            const sweep = Math.PI * 1.5

            context.lineCap = "round"
            context.lineWidth = thickness

            context.beginPath()
            context.arc(centreX, centreY, radius, start, start + sweep)
            context.strokeStyle = Theme.grid
            context.stroke()

            if (root.fraction > 0) {
                context.beginPath()
                context.arc(centreX, centreY, radius, start, start + sweep * root.fraction)
                context.strokeStyle = root.arcColor
                context.stroke()
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * 0.08
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: MetricFormat.format(root.value, root.unit, root.decimals)
            color: root.arcColor
            font.pixelSize: Math.max(16, Math.min(root.height * 0.22, root.width * 0.18))
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: MetricFormat.format(root.minimum, root.unit, 0) + " – " + MetricFormat.format(root.maximum, root.unit, 0)
            color: Theme.textFaint
            font.pixelSize: 10
        }
    }

    onValueChanged: arc.requestPaint()
    onMaximumChanged: arc.requestPaint()
}
