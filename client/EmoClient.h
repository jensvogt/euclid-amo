#pragma once

#include <QJsonArray>
#include <QMap>
#include <QObject>
#include <QSet>
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

    // What there is to chart: every metric name stored, with the label keys seen on it and the
    // values seen under each.
    //
    // Assembled here from unfiltered reads rather than asked for, because EMO has no action that
    // enumerates its series - "list" filters, it does not describe. Since a read is bounded by
    // `limit` and answers newest first, what any one of them sees is "whatever was written most
    // recently", which is why this reads two tiers and merges them:
    //
    //   DAY  - one row per series per day, so a tier small enough that `limit` covers all of it.
    //          This is what makes a metric that has stopped - an import job's counters between
    //          runs, a module that was restarted - appear at all.
    //   RAW  - five-minute buckets, where a metric first written minutes ago already is and the
    //          day rollup has not yet reached.
    //
    // Either tier alone leaves a hole; the union has none worth caring about. catalogLoaded() is
    // emitted after each answer with everything known so far, so a failure of one still leaves the
    // picker populated from the other.
    Q_INVOKABLE void fetchCatalog(int limit = 2000);

signals:
    // `series` is [{name, points: [{timestamp, value, maxValue}]}], oldest first so a chart can
    // draw it left to right. The four figures are over everything that matched, for the panels that
    // show one number rather than a line.
    void seriesLoaded(const QString &panelId, const QVariantList &series,
                      double latest, double minimum, double maximum, double total);
    void seriesFailed(const QString &panelId, const QString &message);

    // The data loaded, but more than one row landed on the same point of the same line - so the
    // line joins values that are not successive readings of one thing. Its own signal rather than
    // an error: the panel keeps its chart and says what would make it a chart of one series.
    void seriesAmbiguous(const QString &panelId, const QString &message);

    // [{name, labelKeys: [...], labelValues: {key: [value, ...]}}], by metric name.
    void catalogLoaded(const QVariantList &metrics);
    void catalogFailed(const QString &message);

private:
    // One tier's answer folded into m_catalog, then the whole of it emitted. Merging rather than
    // replacing is the point: the two reads arrive separately and neither is complete alone.
    void mergeCatalog(const QJsonArray &items);

    // {metric name: {label key: values seen}}, across every tier read so far. Sorted containers
    // throughout, so the picker's order is the collation order and not the order rows happened to
    // arrive in.
    QMap<QString, QMap<QString, QSet<QString>>> m_catalog;

    EuclidBaseClient *m_base;
};
