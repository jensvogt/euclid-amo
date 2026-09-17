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
