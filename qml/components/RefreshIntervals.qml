pragma Singleton
import QtQuick

// How often the wall re-asks, offered in two places: the toolbar, where it is reached for, and
// Settings, where it is found by somebody looking for it.
//
// A singleton because it is offered twice. The table lived on the toolbar once and was passed into
// the dialogs that needed it, then moved into Settings when the toolbar control was taken away,
// and both times the seconds behind "1m" were one copy-and-paste from disagreeing with themselves.
// It is one interval for the whole application - see AppSettings::autoRefreshSeconds - so it is
// one table.
QtObject {
    // Two labels for one interval: the toolbar has room for "30s" between the range buttons and
    // the lock, and a settings dialog reads better saying what it means.
    readonly property var options: [
        {short: "off", long: "off", seconds: 0},
        {short: "10s", long: "10 seconds", seconds: 10},
        {short: "30s", long: "30 seconds", seconds: 30},
        {short: "1m", long: "1 minute", seconds: 60},
        {short: "5m", long: "5 minutes", seconds: 300},
        {short: "15m", long: "15 minutes", seconds: 900}
    ]

    function shortLabels() {
        const out = []
        for (const option of options) out.push(option.short)
        return out
    }

    function longLabels() {
        const out = []
        for (const option of options) out.push(option.long)
        return out
    }

    // Where an interval sits in the table, for the combo boxes that have to be told rather than
    // bound: a ComboBox writes its own currentIndex as it populates. An interval the table does
    // not carry - one left in a settings file by hand - shows as the first entry rather than as
    // nothing at all.
    function indexOf(seconds) {
        for (let i = 0; i < options.length; ++i) {
            if (options[i].seconds === seconds) return i
        }
        return 0
    }

    function secondsAt(index) {
        return index >= 0 && index < options.length ? options[index].seconds : 0
    }
}
