#include "EmoClient.h"
#include "EuclidBaseClient.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QMap>
#include <QSet>
#include <algorithm>
#include <limits>

namespace {

// The dimensions of one stored row. EMO answers with the map, and with the first pair flattened
// out beside it for readers that predate the map; the map is the one to trust.
QVariantMap labelsOf(const QJsonObject &item) {
    return item.value("labels").toObject().toVariantMap();
}

// What a series of rows is called once it has been split out of the answer. The dimension's value
// alone ("heap", "G1 Eden Space") reads better on a legend than "area=heap" does, and the panel
// title already says which metric this is.
QString seriesNameFor(const QVariantMap &labels, const QString &groupBy, const QString &fallback) {
    if (groupBy.isEmpty()) return fallback;
    const auto value = labels.value(groupBy).toString();
    return value.isEmpty() ? QStringLiteral("(no %1)").arg(groupBy) : value;
}

}// namespace

EmoClient::EmoClient(EuclidBaseClient *baseClient, QObject *parent) : QObject(parent), m_base(baseClient) {}

void EmoClient::fetchSeries(const QString &panelId, const QString &metricName, const QVariantMap &labels,
                            const QString &groupBy, const QString &fromIso, const QString &toIso,
                            const QString &resolution, const int limit) {

    QJsonObject body;
    body["name"] = metricName;
    if (!labels.isEmpty()) {
        QJsonObject filter;
        for (auto it = labels.constBegin(); it != labels.constEnd(); ++it) {
            // Empty means "any value of this dimension", which is not a filter - and sending it as
            // one would ask for the rows whose label is the empty string, of which there are none.
            if (const auto value = it.value().toString(); !value.isEmpty()) filter[it.key()] = value;
        }
        if (!filter.isEmpty()) body["labels"] = filter;
    }
    if (!fromIso.isEmpty()) body["from"] = fromIso;
    if (!toIso.isEmpty()) body["to"] = toIso;
    if (!resolution.isEmpty()) body["resolution"] = resolution;
    body["limit"] = limit;

    m_base->post("emo", "list", body, true,
         [this, panelId, groupBy, metricName](const QJsonObject &response) {
             // Grouped in insertion order rather than by name: the first series to appear is drawn
             // first and keeps its colour across refreshes, which a sorted map would shuffle every
             // time a new dimension value turned up.
             QList<QString> order;
             QMap<QString, QVariantList> pointsByName;

             double latest = 0, minimum = std::numeric_limits<double>::max(), maximum = std::numeric_limits<double>::lowest(), total = 0;
             QString latestStamp;
             bool any = false;

             // Rows that land in the same series at the same instant. A series is named by the
             // group-by value alone, so any dimension the query did not name still varies inside
             // it - jvm.memory.used carries application-name, area *and* id, and splitting by the
             // first of those puts eight memory pools on one line, which is then drawn jumping
             // between 1.8 MB and 259 MB at every bucket. It looks like a spike and is an artefact.
             //
             // Counted rather than merged: what the right answer is depends on what is being asked
             // (sum the pools? chart one? one line each?), and picking one here would be this class
             // inventing an aggregation nobody asked for. So it reports, and the panel says so.
             QHash<QString, QVariantMap> firstRowInSlot;
             QHash<QString, int> rowsInSlot;
             QSet<QString> ambiguousKeys;
             int slotsWithCollisions = 0, worstRowsInSlot = 1;

             const QJsonArray items = response.value("items").toArray();
             // EMO answers newest first; a chart wants oldest first, so this walks backwards.
             for (auto it = items.constEnd(); it != items.constBegin();) {
                 --it;
                 const QJsonObject item = (*it).toObject();
                 const QVariantMap rowLabels = labelsOf(item);
                 const QString name = seriesNameFor(rowLabels, groupBy, metricName);

                 QVariantMap point;
                 const auto stamp = item.value("timestamp").toString();
                 const auto value = item.value("value").toDouble();
                 point["timestamp"] = stamp;
                 point["value"] = value;
                 // The peak within the bucket as well as its mean. For anything bursty they are
                 // different questions, and a five-minute mean reports a twenty-second saturation
                 // as though it never happened.
                 point["maxValue"] = item.value("maxValue").toDouble();
                 point["labels"] = rowLabels;

                 // The slot a point occupies on the chart: one series, one instant. A second row
                 // in the same slot is the collision above.
                 const QString slot = name + QChar(QChar::Null) + stamp;
                 if (const auto existing = firstRowInSlot.constFind(slot); existing != firstRowInSlot.constEnd()) {
                     const int rows = ++rowsInSlot[slot];
                     if (rows == 2) ++slotsWithCollisions;
                     worstRowsInSlot = std::max(worstRowsInSlot, rows);

                     // Which dimensions actually differ, over the union of both rows' keys: a row
                     // that carries no labels at all differs from one that does by every key it is
                     // missing, and looking only at the row in hand would miss that.
                     QSet<QString> keys;
                     for (auto k = rowLabels.constBegin(); k != rowLabels.constEnd(); ++k) keys.insert(k.key());
                     for (auto k = existing->constBegin(); k != existing->constEnd(); ++k) keys.insert(k.key());
                     for (const auto &key: keys) {
                         if (existing->value(key) != rowLabels.value(key)) ambiguousKeys.insert(key);
                     }
                 } else {
                     firstRowInSlot.insert(slot, rowLabels);
                     rowsInSlot.insert(slot, 1);
                 }

                 if (!pointsByName.contains(name)) order.append(name);
                 pointsByName[name].append(point);

                 any = true;
                 total += value;
                 minimum = std::min(minimum, value);
                 maximum = std::max(maximum, value);
                 // "Latest" is by timestamp, not by position: the rows arrive grouped by series, so
                 // the last one walked belongs to whichever series happened to come last.
                 if (stamp >= latestStamp) {
                     latestStamp = stamp;
                     latest = value;
                 }
             }

             QVariantList series;
             for (const auto &name: order) {
                 QVariantMap entry;
                 entry["name"] = name;
                 entry["points"] = pointsByName.value(name);
                 series.append(entry);
             }

             emit seriesLoaded(panelId, series, latest, any ? minimum : 0.0, any ? maximum : 0.0, total);

             // After the data, not instead of it. How wrong the chart is depends on how much of it
             // collides: eight pools on one line at every instant is a chart of nothing, while one
             // bucket from before an application started sending a label is one spurious step in an
             // otherwise honest line. Both are worth saying; neither is worth hiding the line over,
             // so this rides alongside and the panel reports how many points are affected.
             if (slotsWithCollisions > 0) {
                 QStringList keys(ambiguousKeys.constBegin(), ambiguousKeys.constEnd());
                 keys.sort();
                 emit seriesAmbiguous(panelId,
                                      tr("%1 rows share one point at %2 of %3 - the line joins them. "
                                         "Split by or filter on %4.")
                                              .arg(worstRowsInSlot)
                                              .arg(slotsWithCollisions)
                                              .arg(firstRowInSlot.size())
                                              .arg(keys.isEmpty() ? tr("another dimension") : keys.join(QStringLiteral(", "))));
             }
         },
         [this, panelId](const QString &message) {
             emit seriesFailed(panelId, message);
         });
}

void EmoClient::mergeCatalog(const QJsonArray &items) {

    for (const auto &value: items) {
        const QJsonObject item = value.toObject();
        const auto name = item.value("name").toString();
        if (name.isEmpty()) continue;

        // Touched even when it carries no labels, so a metric with no dimensions at all is still
        // a metric the picker offers.
        auto &keys = m_catalog[name];
        const QVariantMap labels = labelsOf(item);
        for (auto it = labels.constBegin(); it != labels.constEnd(); ++it) {
            keys[it.key()].insert(it.value().toString());
        }
    }

    QVariantList metrics;
    for (auto entryIt = m_catalog.constBegin(); entryIt != m_catalog.constEnd(); ++entryIt) {
        QVariantMap entry;
        entry["name"] = entryIt.key();

        QStringList labelKeys;
        QVariantMap labelValues;
        for (auto it = entryIt.value().constBegin(); it != entryIt.value().constEnd(); ++it) {
            labelKeys.append(it.key());
            QStringList values(it.value().constBegin(), it.value().constEnd());
            values.sort();
            labelValues[it.key()] = values;
        }

        entry["labelKeys"] = labelKeys;
        entry["labelValues"] = labelValues;
        metrics.append(entry);
    }

    emit catalogLoaded(metrics);
}

void EmoClient::fetchCatalog(const int limit) {

    m_catalog.clear();

    // DAY first: it is the small, complete one, so the picker is usable from the first answer and
    // the RAW read only ever adds to it.
    for (const auto &resolution: {QStringLiteral("DAY"), QStringLiteral("RAW")}) {
        QJsonObject body;
        body["limit"] = limit;
        body["resolution"] = resolution;

        m_base->post("emo", "list", body, true,
             [this](const QJsonObject &response) {
                 mergeCatalog(response.value("items").toArray());
             },
             [this](const QString &message) {
                 emit catalogFailed(message);
             });
    }
}
