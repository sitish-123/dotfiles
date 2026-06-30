// ai-sidebar — a real layer-shell sidebar (like the old Quickshell one) that embeds the
// LOGGED-IN web apps for Gemini / ChatGPT / Claude. Uses QtWebEngine (Chromium, so Google
// login works) + LayerShellQt (true layer surface). Single-instance: launching it again
// just toggles visibility, so SUPER+A behaves exactly like the old sidebar toggle.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtWebEngineQuick/QtWebEngineQuick>
#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>
#include <QWindow>
#include <QMargins>
#include <QScreen>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <LayerShellQt/Window>

static QByteArray hyprctlJson(const QStringList &args) {
    QProcess p;
    p.start(QStringLiteral("hyprctl"), args);
    return p.waitForFinished(1500) ? p.readAllStandardOutput() : QByteArray();
}

// Bottom margin to clear the bottom bar, computed LIVE from Hyprland (not a magic number).
// The bar is bottom-anchored (its bottom edge == the screen bottom), so the margin we need
// from the screen bottom is simply the bar's height + a small gap. Reading the bar's height
// (h) sidesteps any logical/physical screen-size mismatch. Adapts if the bar height changes.
static int bottomMarginForBar(int gap, int fallback) {
    int barH = -1;
    const QJsonObject root = QJsonDocument::fromJson(hyprctlJson({"layers", "-j"})).object();
    for (const QJsonValue &mon : root) {
        const QJsonObject levels = mon.toObject().value("levels").toObject();
        for (const QJsonValue &lvl : levels) {
            for (const QJsonValue &layerV : lvl.toArray()) {
                const QJsonObject layer = layerV.toObject();
                if (layer.value("namespace").toString().startsWith("quickshell:bar"))
                    barH = layer.value("h").toInt();
            }
        }
    }
    return barH > 0 ? barH + gap : fallback;
}

class Controller : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool shown READ shown WRITE setShown NOTIFY shownChanged)
public:
    bool shown() const { return m_shown; }
    void setShown(bool s) { if (s != m_shown) { m_shown = s; emit shownChanged(); } }
    Q_INVOKABLE void toggle() { setShown(!m_shown); }
signals:
    void shownChanged();
private:
    bool m_shown = true;
};

int main(int argc, char *argv[]) {
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ai-sidebar"));
    app.setDesktopFileName(QStringLiteral("ai-sidebar"));

    // Single instance: if one is already running, tell it to toggle and exit. This makes
    // re-running the binary (SUPER+A) a show/hide toggle, like the old sidebar.
    const QString serverName = QStringLiteral("ii-ai-sidebar");
    {
        QLocalSocket probe;
        probe.connectToServer(serverName);
        if (probe.waitForConnected(200)) {
            probe.write("toggle");
            probe.flush();
            probe.waitForBytesWritten(300);
            return 0;
        }
    }

    Controller controller;
    QLocalServer::removeServer(serverName);
    QLocalServer server;
    server.listen(serverName);
    QObject::connect(&server, &QLocalServer::newConnection, [&server, &controller]() {
        QLocalSocket *c = server.nextPendingConnection();
        QObject::connect(c, &QLocalSocket::readyRead, [c, &controller]() {
            c->readAll();
            controller.toggle();
            c->deleteLater();
        });
    });

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Controller"), &controller);
    engine.loadFromModule("aisidebar", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    // Float the SURFACE: small gap top/left (matches the right sidebar), and a bottom margin
    // computed live so it always sits just above the bar. QMargins(left, top, right, bottom).
    if (auto *qw = qobject_cast<QWindow *>(engine.rootObjects().constFirst())) {
        if (auto *ls = LayerShellQt::Window::get(qw)) {
            const int gap = 8;
            ls->setMargins(QMargins(gap, gap, 0, bottomMarginForBar(gap, 82)));
        }
    }
    return app.exec();
}

#include "main.moc"
