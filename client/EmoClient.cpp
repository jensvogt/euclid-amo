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
                            const QString &resolution, const QString &combine, const int limit) {

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
         [this, panelId, groupBy, metricName, combine](const QJsonObject &response) {
             // Grouped in insertion order rather than by name: the first series to appear is drawn
             // first and keeps its colour across refreshes, which a sorted map would shuffle every
             // time a new dimension value turned up.
             QList<QString> order;
             QMap<QString, QVariantList> pointsByName;

             // Rows that land in the same series at the same instant. A series is named by the
             // group-by value alone, so any dimension the query did not name still varies inside
             // it: two instances of one application, or the eight memory pools jvm.memory.used
             // carries under application-name.
             //
             // What to do about that is the caller's decision, because the right answer depends on
             // the question - the mean across instances, the sum of the pools, or one line each
             // from a finer split. "none" keeps every row as its own point, which draws them joined
             // and is reported as ambiguous; anything else folds them into one point here.
             QHash<QString, QVariantMap> firstRowInSlot;
             QHash<QString, int> rowsInSlot;
             QHash<QString, int> pointIndexInSlot;
             QSet<QString> ambiguousKeys;
             int slotsWithCollisions = 0, worstRowsInSlot = 1;
             const bool folding = combine != QLatin1String("none") && !combine.isEmpty();

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

                 if (folding && pointIndexInSlot.contains(slot)) {
                     // Folded into the point already standing there. The running mean is kept
                     // rather than a sum and a count, so a series of any length costs two numbers.
                     auto &points = pointsByName[name];
                     const int index = pointIndexInSlot.value(slot);
                     QVariantMap merged = points.at(index).toMap();
                     const double sofar = merged.value(QStringLiteral("value")).toDouble();
                     const int rows = rowsInSlot.value(slot);

                     if (combine == QLatin1String("average")) merged["value"] = sofar + (value - sofar) / rows;
                     else if (combine == QLatin1String("sum")) merged["value"] = sofar + value;
                     else if (combine == QLatin1String("max")) merged["value"] = std::max(sofar, value);
                     else if (combine == QLatin1String("min")) merged["value"] = std::min(sofar, value);

                     // The bucket's peak is a peak however the means are folded: the highest of the
                     // rows is the highest anything reached in that bucket.
                     merged["maxValue"] = std::max(merged.value(QStringLiteral("maxValue")).toDouble(),
                                                   point.value(QStringLiteral("maxValue")).toDouble());
                     points[index] = merged;
                 } else {
                     pointIndexInSlot.insert(slot, static_cast<int>(pointsByName[name].size()));
                     pointsByName[name].append(point);
                 }
             }

             QVariantList series;
             for (const auto &name: order) {
                 QVariantMap entry;
                 entry["name"] = name;
                 entry["points"] = pointsByName.value(name);
                 series.append(entry);
             }

             // The four figures the number panels show, taken from the points as they ended up
             // rather than from the rows that went in. With rows folded together those are no
             // longer the same set, and a stat reading the raw rows would report a total of
             // values its own chart never drew.
             double latest = 0, minimum = std::numeric_limits<double>::max();
             double maximum = std::numeric_limits<double>::lowest(), total = 0;
             QString latestStamp;
             bool any = false;
             for (const auto &entry: series) {
                 for (const auto &value: entry.toMap().value(QStringLiteral("points")).toList()) {
                     const QVariantMap point = value.toMap();
                     const double number = point.value(QStringLiteral("value")).toDouble();
                     const QString stamp = point.value(QStringLiteral("timestamp")).toString();
                     any = true;
                     total += number;
                     minimum = std::min(minimum, number);
                     maximum = std::max(maximum, number);
                     // "Latest" is by timestamp, not by position: the points arrive grouped by
                     // series, so the last one walked belongs to whichever series came last.
                     if (stamp >= latestStamp) {
                         latestStamp = stamp;
                         latest = number;
                     }
                 }
             }

             emit seriesLoaded(panelId, series, latest, any ? minimum : 0.0, any ? maximum : 0.0, total);

             // After the data, not instead of it. How wrong the chart is depends on how much of it
             // collides: eight pools on one line at every instant is a chart of nothing, while one
             // bucket from before an application started sending a label is one spurious step in an
             // otherwise honest line. Both are worth saying; neither is worth hiding the line over,
             // so this rides alongside and the panel reports how many points are affected.
             if (slotsWithCollisions > 0 && !folding) {
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

// ── Saved dashboards ─────────────────────────────────────────────────────────
//
// Thin by design: EMO owns what a dashboard is keyed by and who it belongs to, so there is nothing
// to decide on this side beyond turning a QVariantMap into JSON and back. In particular none of
// these sends a user id - see EmoClient.h.

void EmoClient::saveDashboard(const QString &name, const QVariantMap &dashboard) {

    QJsonObject body;
    body["name"] = name;
    body["dashboard"] = QJsonObject::fromVariantMap(dashboard);

    m_base->post("emo", "save-dashboard", body, true,
         [this, name](const QJsonObject &) {
             emit dashboardSaved(name);
         },
         [this, name](const QString &message) {
             emit dashboardSaveFailed(name, message);
         });
}

void EmoClient::loadDashboard(const QString &name) {

    QJsonObject body;
    body["name"] = name;

    m_base->post("emo", "get-dashboard", body, true,
         [this, name](const QJsonObject &response) {
             const auto layout = response.value("dashboard").toObject();
             // An answer with no layout in it is a failure rather than an empty dashboard: opening
             // it would replace the wall on screen with nothing, which is indistinguishable from
             // having deleted it.
             if (layout.isEmpty()) {
                 emit dashboardLoadFailed(name, QStringLiteral("The server returned no layout for \"%1\".").arg(name));
                 return;
             }
             emit dashboardLoaded(name, layout.toVariantMap());
         },
         [this, name](const QString &message) {
             emit dashboardLoadFailed(name, message);
         });
}

void EmoClient::listDashboards() {

    m_base->post("emo", "list-dashboards", QJsonObject{}, true,
         [this](const QJsonObject &response) {
             QVariantList items;
             for (const auto &item: response.value("items").toArray()) {
                 items.append(item.toObject().toVariantMap());
             }
             emit dashboardsListed(items);
         },
         [this](const QString &message) {
             emit dashboardsListFailed(message);
         });
}
