pragma Singleton
import QtQuick

// The time ranges, and what each one means to EMO.
//
// A table rather than a list of durations, because a range doubles as a resolution hint: EMO stores
// three tiers - RAW five-minute buckets, HOUR, DAY - and asking for a week of RAW is both slower
// and less readable than asking for a week of HOUR, the same line drawn from 2,016 points instead
// of 168.
//
// It lives here rather than on the bar because two toolbars read it now: the main window's and
// every detached window's. A table that belonged to one of them would be a table the other had to
// be handed, and the tooltips with it.
QtObject {
    readonly property var table: [
        {label: "15m", seconds: 900, resolution: "RAW"},
        {label: "1h", seconds: 3600, resolution: "RAW"},
        {label: "6h", seconds: 21600, resolution: "RAW"},
        {label: "24h", seconds: 86400, resolution: "HOUR"},
        {label: "7d", seconds: 604800, resolution: "HOUR"},
        {label: "30d", seconds: 2592000, resolution: "DAY"}
    ]

    // What one point of each tier actually is. This is the part of a range that is not on the
    // button: 30d draws a point per day, so a spike that lasted an afternoon is not on that chart
    // at all - it is inside one of its points, averaged away with the rest of the day.
    readonly property var tierSeconds: ({"RAW": 300, "HOUR": 3600, "DAY": 86400})

    // Which tier a window of this length should be read from, taken from the table rather than
    // written out again: the longest range that fits inside it answers for it.
    //
    // That way a custom window lands on the same tier as the button of the same length - a day
    // typed in reads HOUR exactly as 24h does - and the ones in between inherit from the shorter
    // neighbour rather than the longer. Nine hours asked of the HOUR tier is nine points; asked of
    // RAW it is a hundred and eight, which is what somebody picking nine hours wanted to see.
    function resolutionForSeconds(seconds) {
        let resolution = table[0].resolution
        for (const entry of table) {
            if (entry.seconds <= seconds) resolution = entry.resolution
        }
        return resolution
    }

    // The entry a dashboard's range names, custom windows included. Used by the bars to light a
    // button, and by Main to decide what to ask EMO for.
    function entryFor(range, customFrom, customTo) {
        if (range === "custom") {
            const from = Date.parse(customFrom)
            const to = Date.parse(customTo)
            const seconds = (!isNaN(from) && !isNaN(to) && to > from) ? (to - from) / 1000 : 0
            if (seconds > 0)
                return {label: "custom", seconds: seconds, resolution: resolutionForSeconds(seconds)}
        }
        for (const entry of table) {
            if (entry.label === range) return entry
        }
        return table[1]
    }

    // Short enough for a button: "45m", "6h", "3d".
    function formatSpan(seconds) {
        if (seconds >= 86400) return Math.round(seconds / 86400) + "d"
        if (seconds >= 3600) return Math.round(seconds / 3600) + "h"
        return Math.max(1, Math.round(seconds / 60)) + "m"
    }

    function bucketWords(resolution) {
        switch (resolution) {
        case "RAW": return "5-minute averages"
        case "HOUR": return "hourly averages"
        case "DAY": return "daily averages"
        }
        return resolution
    }

    // "5-minute averages · 72 points", the second half being what the first means for this
    // particular window - the figure that says whether a line will show detail or a trend.
    function tierWords(seconds, resolution) {
        const bucket = tierSeconds[resolution] || 0
        if (!(bucket > 0) || !(seconds > 0)) return bucketWords(resolution)
        return bucketWords(resolution) + "  ·  " + Math.max(1, Math.round(seconds / bucket)) + " points"
    }

    // The span in words rather than in the button's shorthand: a tooltip is read, not scanned.
    function spanWords(seconds) {
        if (seconds >= 86400 && seconds % 86400 === 0) {
            const days = seconds / 86400
            return days === 1 ? "The last 24 hours" : "The last " + days + " days"
        }
        if (seconds >= 3600 && seconds % 3600 === 0) {
            const hours = seconds / 3600
            return hours === 1 ? "The last hour" : "The last " + hours + " hours"
        }
        return "The last " + Math.max(1, Math.round(seconds / 60)) + " minutes"
    }

    function rangeTip(entry) {
        return spanWords(entry.seconds) + "\n" + tierWords(entry.seconds, entry.resolution)
    }
}
