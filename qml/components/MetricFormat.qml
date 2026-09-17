pragma Singleton
import QtQuick

// How a number is written on a panel.
//
// The unit is the panel's own setting rather than something read from the metric, because EMO does
// not record one: a value is a double and what it counts is the name's business. So a panel that
// knows it is showing bytes says so, and one that does not shows a plain number rather than
// guessing from a name that happens to end in "-size".
QtObject {
    readonly property var units: ["", "%", "bytes", "ms", "s", "/s", "count"]

    function format(value, unit, decimals) {
        if (value === undefined || value === null || isNaN(value))
            return "—"

        const places = decimals === undefined ? 0 : decimals
        switch (unit) {
        case "bytes":
            return bytes(value)
        case "ms":
            return duration(value)
        case "s":
            return duration(value * 1000)
        case "%":
            return value.toFixed(places === 0 ? 1 : places) + "%"
        case "/s":
            return compact(value, places) + "/s"
        default:
            return compact(value, places)
        }
    }

    // Thousands separated rather than abbreviated below a million: a queue of 12,480 messages is a
    // different thing to know than "12K", and there is room for it on a panel.
    function compact(value, decimals) {
        const places = decimals === undefined ? 0 : decimals
        if (Math.abs(value) >= 1e9) return (value / 1e9).toFixed(1) + "B"
        if (Math.abs(value) >= 1e6) return (value / 1e6).toFixed(1) + "M"
        return Number(value.toFixed(places)).toLocaleString(Qt.locale(), "f", places)
    }

    // Steps of 1000, with kB/MB/GB to match. Both conventions are defensible, but the label is what
    // tells a reader which one is being applied, and these labels are the decimal ones: dividing by
    // 1024 under them puts a gigabyte of files on screen as "1000.1 MB", which reads as a rollover
    // that failed rather than as the 0.98 GiB it actually is. Binary steps would need KiB/MiB/GiB
    // to be honest about themselves, and that is not what a file size is usually quoted in.
    function bytes(value) {
        const units = ["B", "kB", "MB", "GB", "TB", "PB"]
        const places = unit => unit === 0 ? 0 : 1
        let size = value
        let unit = 0
        // The comparison is against the *rounded* number, not the exact one, because the rounded
        // one is what gets shown: 999,999 bytes is 999.999 kB, which prints as "1000.0 kB" and
        // wants another step. Only the top unit is allowed to print a four-figure number.
        while (unit < units.length - 1 && Math.abs(Number(size.toFixed(places(unit)))) >= 1000) {
            size /= 1000
            unit++
        }
        return size.toFixed(places(unit)) + " " + units[unit]
    }

    function duration(milliseconds) {
        if (Math.abs(milliseconds) < 1000) return milliseconds.toFixed(milliseconds < 10 ? 1 : 0) + " ms"
        const seconds = milliseconds / 1000
        if (Math.abs(seconds) < 60) return seconds.toFixed(1) + " s"
        const minutes = seconds / 60
        if (Math.abs(minutes) < 60) return minutes.toFixed(1) + " min"
        return (minutes / 60).toFixed(1) + " h"
    }
}
