#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

// Where a dashboard lives: one JSON file per dashboard under $HOME/.euclid/amo/dashboards.
//
// A file per dashboard rather than one document holding all of them, for the reason Grafana keeps
// them apart too: a dashboard is a thing somebody edits, breaks, copies to another machine and
// puts in a repository, and all four of those are file operations. It also means a dashboard whose
// JSON has been hand-edited into something unreadable costs its owner that dashboard rather than
// every dashboard.
//
// Nothing here validates a panel's contents. A panel is whatever the QML wrote into it, which is
// what keeps a new panel type from needing a schema change down here; the editor is the only thing
// that knows what a panel needs, and it is the only thing that reads one back.
class DashboardStore : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList names READ names NOTIFY namesChanged)

public:
    explicit DashboardStore(QObject *parent = nullptr);

    // Every dashboard on disk, by name, sorted. The file name is the dashboard name, so a name
    // that cannot be a file name is refused by save().
    [[nodiscard]]
    QStringList names() const { return m_names; }

    // The dashboard, or an empty map when there is no such file or it cannot be parsed. Reading is
    // deliberately quiet: a dashboard that will not load is reported by the caller as an empty
    // wall, not by this class as an error dialog nobody asked for.
    Q_INVOKABLE QVariantMap load(const QString &name) const;

    // Writes it, creating the directory if it is not there. Returns false and says why in
    // lastError() if the name is unusable or the file cannot be written.
    Q_INVOKABLE bool save(const QString &name, const QVariantMap &dashboard);

    Q_INVOKABLE bool remove(const QString &name);

    // A dashboard with nothing on it, which is what "New dashboard" starts from.
    Q_INVOKABLE QVariantMap emptyDashboard(const QString &name) const;

    // What a first run gets: a wall showing the installation's own vital signs, so that the
    // application has something on it before anybody has configured anything. Built from the
    // metrics EMO records about itself, which are the only ones certain to exist.
    Q_INVOKABLE QVariantMap starterDashboard() const;

    [[nodiscard]]
    Q_INVOKABLE QString lastError() const { return m_lastError; }

    // Where the files are, for the settings dialog to show.
    [[nodiscard]]
    Q_INVOKABLE QString directory() const;

signals:
    void namesChanged();

private:
    void refresh();

    [[nodiscard]]
    QString pathFor(const QString &name) const;

    QStringList m_names;
    QString m_lastError;
};
