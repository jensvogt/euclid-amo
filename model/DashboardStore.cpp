#include "DashboardStore.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

namespace {

// A dashboard name has to survive being a file name on every platform this may run on, so it is
// held to the intersection rather than to what the current one happens to allow.
bool usableAsFileName(const QString &name) {
    static const QRegularExpression allowed(QStringLiteral("^[A-Za-z0-9 ._-]{1,64}$"));
    return allowed.match(name).hasMatch() && name != QStringLiteral(".") && name != QStringLiteral("..");
}

QVariantMap panel(const QString &id, const QString &title, const QString &type, const QString &metric,
                  const QString &groupBy, const QString &unit,
                  const int x, const int y, const int w, const int h) {
    QVariantMap p;
    p["id"] = id;
    p["title"] = title;
    p["type"] = type;
    p["metric"] = metric;
    p["labels"] = QVariantMap{};
    p["groupBy"] = groupBy;
    p["unit"] = unit;
    p["decimals"] = 0;
    // Which figure over the window a stat or a bar shows; ignored by the other panel types. The
    // same three words BarChart reads - "latest", "max", "total".
    p["reduce"] = QStringLiteral("latest");
    // Empty means "whatever the dashboard is showing". A panel can pin its own range - a stat of
    // the last hour beside a week-long chart - and this is where that would be written.
    p["range"] = QString();
    p["x"] = x;
    p["y"] = y;
    p["w"] = w;
    p["h"] = h;
    return p;
}

}// namespace

DashboardStore::DashboardStore(QObject *parent) : QObject(parent) {
    refresh();
}

QString DashboardStore::directory() const {
    return QDir::homePath() + QStringLiteral("/.euclid/amo/dashboards");
}

QString DashboardStore::pathFor(const QString &name) const {
    return directory() + QStringLiteral("/") + name + QStringLiteral(".json");
}

void DashboardStore::refresh() {

    QStringList found;
    if (const QDir dir(directory()); dir.exists()) {
        for (const auto &entry: dir.entryList({QStringLiteral("*.json")}, QDir::Files, QDir::Name)) {
            found.append(entry.left(entry.size() - 5));
        }
    }

    if (found == m_names) return;
    m_names = found;
    emit namesChanged();
}

QVariantMap DashboardStore::load(const QString &name) const {

    QFile file(pathFor(name));
    if (!file.open(QIODevice::ReadOnly)) return {};

    QJsonParseError error{};
    const auto document = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) return {};

    auto dashboard = document.object().toVariantMap();
    // The name comes from the file, not from the document: renaming the file is how a dashboard is
    // renamed, and a "name" inside that disagrees would make the list and the title say different
    // things.
    dashboard["name"] = name;
    return dashboard;
}

bool DashboardStore::save(const QString &name, const QVariantMap &dashboard) {

    if (!usableAsFileName(name)) {
        m_lastError = QStringLiteral("\"%1\" cannot be a dashboard name - letters, digits, spaces, "
                                     "dots, dashes and underscores only, up to 64 characters.").arg(name);
        return false;
    }

    if (!QDir().mkpath(directory())) {
        m_lastError = QStringLiteral("Could not create %1").arg(directory());
        return false;
    }

    auto document = dashboard;
    document["name"] = name;

    // QSaveFile rather than QFile: a dashboard is written on every edit, and a crash halfway
    // through would otherwise leave a truncated file where a working one used to be.
    QSaveFile file(pathFor(name));
    if (!file.open(QIODevice::WriteOnly)) {
        m_lastError = QStringLiteral("Could not write %1").arg(file.fileName());
        return false;
    }

    file.write(QJsonDocument(QJsonObject::fromVariantMap(document)).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        m_lastError = QStringLiteral("Could not write %1").arg(file.fileName());
        return false;
    }

    m_lastError.clear();
    refresh();
    return true;
}

bool DashboardStore::remove(const QString &name) {

    if (!usableAsFileName(name)) {
        m_lastError = QStringLiteral("\"%1\" is not a dashboard this can remove.").arg(name);
        return false;
    }
    if (!QFile::remove(pathFor(name))) {
        m_lastError = QStringLiteral("Could not remove %1").arg(pathFor(name));
        return false;
    }

    m_lastError.clear();
    refresh();
    return true;
}

QVariantMap DashboardStore::emptyDashboard(const QString &name) const {
    QVariantMap dashboard;
    dashboard["name"] = name;
    dashboard["range"] = QStringLiteral("1h");
    dashboard["resolution"] = QStringLiteral("RAW");
    dashboard["refreshSeconds"] = 30;
    dashboard["panels"] = QVariantList{};
    return dashboard;
}

QVariantMap DashboardStore::starterDashboard() const {

    auto dashboard = emptyDashboard(QStringLiteral("Overview"));

    // The machine, the database and the module pools - everything EMO collects about the
    // installation without anybody having pushed anything. A first run therefore shows a working
    // wall rather than an empty grid with an "add panel" button on it, which is the difference
    // between an application that looks broken and one that looks ready.
    //
    // 24 columns wide, the same unit the grid uses; see DashboardGrid.qml.
    dashboard["panels"] = QVariantList{
            panel("cpu", "CPU", "stat", "system-cpu-usage", QString(), "%", 0, 0, 4, 3),
            panel("memory", "Memory", "gauge", "system-memory-usage-percent", QString(), "%", 4, 0, 4, 3),
            panel("db-size", "Database size", "stat", "database-total-size", QString(), "bytes", 8, 0, 4, 3),
            panel("gateway", "Gateway requests", "line", "gateway-service-count", "method", QString(), 12, 0, 12, 6),
            panel("cpu-history", "CPU over time", "line", "system-cpu-usage", "host", "%", 0, 3, 12, 6),
            panel("instances", "Module instances", "bar", "module-instances", "module", QString(), 0, 9, 12, 6),
            panel("utilisation", "Pool utilisation", "line", "module-utilisation", "module", "%", 12, 9, 12, 6),
    };
    return dashboard;
}
