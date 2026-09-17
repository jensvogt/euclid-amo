pragma Singleton
import QtQuick

// One place for the wall's colours, because a dashboard is read at a distance and across many
// panels: a chart that picks its own blue is the one that looks broken next to seven that agreed.
QtObject {
    // Surfaces, darkest first: the page behind everything, a panel, a panel's header strip.
    readonly property color background: "#12141a"
    readonly property color panel: "#1b1e25"
    readonly property color panelHeader: "#20242e"
    readonly property color border: "#2c313c"
    readonly property color borderActive: "#4f8cff"
    readonly property color grid: "#232833"

    readonly property color text: "#e5e7eb"
    readonly property color textMuted: "#9aa1ac"
    readonly property color textFaint: "#6b7280"

    readonly property color accent: "#4f8cff"
    readonly property color good: "#4cd97b"
    readonly property color warn: "#e0a458"
    readonly property color bad: "#ff6b6b"

    // The series palette, in the order lines are handed out. Chosen to stay apart at a glance and
    // to survive being drawn one pixel wide: adjacent entries differ in lightness as well as hue,
    // so a line is still identifiable to somebody who cannot tell the two greens apart.
    readonly property var series: ["#4f8cff", "#4cd97b", "#e0a458", "#c56bff", "#39c0d3",
                                   "#ff6b6b", "#8fd14f", "#f78fb3", "#7c9cff", "#d3b239"]

    function seriesColor(index) {
        return series[index % series.length]
    }
}
