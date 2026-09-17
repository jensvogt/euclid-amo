#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "AppSettings.h"
#include "client/EmoClient.h"
#include "client/EuclidBaseClient.h"
#include "model/DashboardStore.h"

int main(int argc, char *argv[]) {

    const QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName("Euclid");
    QGuiApplication::setApplicationName("Euclid AMO");
    QGuiApplication::setApplicationVersion(QStringLiteral(APP_VERSION));
    QGuiApplication::setDesktopFileName(QStringLiteral("euclid-amo"));

    QCommandLineParser parser;
    parser.setApplicationDescription("Euclid AMO - application monitoring dashboards over the euclid monitoring module");
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption userOption(QStringList{"user", "u"}, "Username or email to sign in with, skipping the login dialog.", "user");
    const QCommandLineOption passwordOption(QStringList{"password", "p"}, "Password to sign in with.", "password");
    const QCommandLineOption namespaceOption(QStringList{"namespace", "n"}, "Namespace to select after signing in; defaults to the first available.", "namespace");
    // A wall on a screen nobody sits at is the point of this application, and a wall that has to be
    // clicked onto the right dashboard after every restart is not one.
    const QCommandLineOption dashboardOption(QStringList{"dashboard", "d"}, "Dashboard to open on start.", "dashboard");
    parser.addOption(userOption);
    parser.addOption(passwordOption);
    parser.addOption(namespaceOption);
    parser.addOption(dashboardOption);
    parser.process(app);

    QQuickStyle::setStyle("Material");

    // Declared before the engine, and that order is the whole point: locals are destroyed in
    // reverse, so the engine goes first and takes every QML object with it while the four objects
    // those objects are bound to are still alive.
    //
    // The other way round - which is the obvious way to write it - each of these dies while the
    // QML that reads it is still standing, and every binding on them re-evaluates against a null
    // context property on the way out: "TypeError: Cannot read property 'names' of null" and one
    // like it for every binding, on every clean exit.
    AppSettings appSettings;
    EuclidBaseClient euclidClient;
    EmoClient emoClient(&euclidClient);
    DashboardStore dashboardStore;

    QQmlApplicationEngine engine;

    // The gateway address lives in the settings, which persist it, and is pushed into the client -
    // neither knows about the other's storage.
    euclidClient.setBaseUrl(appSettings.baseUrl());
    QObject::connect(&appSettings, &AppSettings::baseUrlChanged, &euclidClient,
                     [&appSettings, &euclidClient] { euclidClient.setBaseUrl(appSettings.baseUrl()); });

    const auto applyCredentials = [&appSettings, &euclidClient] {
        euclidClient.setAuthMode(appSettings.authMode());
        euclidClient.setAccessKey(appSettings.accessKeyId(), appSettings.secretAccessKey());
    };
    applyCredentials();
    QObject::connect(&appSettings, &AppSettings::credentialsChanged, &euclidClient, applyCredentials);

    // The other direction, for the one value the gateway issues rather than the operator: the
    // access key that comes back on login, stored so the next start signs with it.
    QObject::connect(&euclidClient, &EuclidBaseClient::accessKeyIssued, &appSettings,
                     [&appSettings](const QString &accessKeyId, const QString &secretAccessKey) {
                         if (appSettings.accessKeyId() == accessKeyId && appSettings.secretAccessKey() == secretAccessKey)
                             return;
                         appSettings.setAccessKeyId(accessKeyId);
                         appSettings.setSecretAccessKey(secretAccessKey);
                     });

    engine.rootContext()->setContextProperty("euclidClient", &euclidClient);
    engine.rootContext()->setContextProperty("emoClient", &emoClient);
    engine.rootContext()->setContextProperty("dashboardStore", &dashboardStore);
    engine.rootContext()->setContextProperty("appSettings", &appSettings);
    engine.rootContext()->setContextProperty("appVersion", QGuiApplication::applicationVersion());
    engine.rootContext()->setContextProperty("qtVersion", QStringLiteral(QT_VERSION_STR));
    engine.rootContext()->setContextProperty("buildDate", QStringLiteral(BUILD_DATE));
    engine.rootContext()->setContextProperty("cliUser", parser.value(userOption));
    engine.rootContext()->setContextProperty("cliPassword", parser.value(passwordOption));
    engine.rootContext()->setContextProperty("cliNamespace", parser.value(namespaceOption));
    engine.rootContext()->setContextProperty("cliDashboard", parser.value(dashboardOption));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QGuiApplication::exit(-1); }, Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/EuclidAmo/qml/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return QGuiApplication::exec();
}
