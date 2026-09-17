#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class EuclidBaseClient;

// EMO (monitoring) reads, shaped for a dashboard rather than for a page.
//
// Two things differ from the same client in the RUI. Every call is keyed by a panel id rather than
// by the metric name, because a wall of panels can perfectly well show one metric three times at
// three resolutions and an answer has to find its way back to the panel that asked for it. And a
// query carries a label map, because a series is identified by however many dimensions the meter
// that produced it carried - {"area": "heap", "id": "G1 Eden Space"} is one series, "area" alone
// is eight of them.
class EmoClient : public QObject {
    Q_OBJECT

public:
    explicit EmoClient(EuclidBaseClient *baseClient, QObject *parent = nullptr);

    // One panel's data. `labels` narrows to the series wanted; `groupBy` names the dimension the
    // rows are split into lines by - empty draws everything that matched as one series.
    //
    // `fromIso`/`toIso` are ISO 8601 instants, or empty for an open end. `resolution` is RAW, HOUR
    // or DAY: the tier to read rather than an aggregation to apply - EMO rolls the tiers up on its
    // own schedule and a query picks one.
    Q_INVOKABLE void fetchSeries(const QString &panelId, const QString &metricName,
                                 const QVariantMap &labels, const QString &groupBy,
                                 const QString &fromIso, const QString &toIso,
                                 const QString &resolution, int limit = 500);

    // What there is to chart: every metric name currently stored, with the label keys seen on it
    // and the values seen under each.
    //
    // Assembled here from one unfiltered read rather than asked for, because EMO has no action
    // that enumerates its series - "list" filters, it does not describe. That makes this an
    // approximation bounded by `limit`: a metric not written within the most recent `limit` rows of
    // the tier is not in the answer. Good enough for a picker, which is all it feeds, and the
    // editor lets a name be typed as well as picked.
    Q_INVOKABLE void fetchCatalog(const QString &resolution = QStringLiteral("RAW"), int limit = 2000);

signals:
    // `series` is [{name, points: [{timestamp, value, maxValue}]}], oldest first so a chart can
    // draw it left to right. The four figures are over everything that matched, for the panels that
    // show one number rather than a line.
    void seriesLoaded(const QString &panelId, const QVariantList &series,
                      double latest, double minimum, double maximum, double total);
    void seriesFailed(const QString &panelId, const QString &message);

    // [{name, labelKeys: [...], labelValues: {key: [value, ...]}}], by metric name.
    void catalogLoaded(const QVariantList &metrics);
    void catalogFailed(const QString &message);

private:
    EuclidBaseClient *m_base;
};
