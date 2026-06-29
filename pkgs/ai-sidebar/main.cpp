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
#include <LayerShellQt/Window>

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

    // Inset the layer SURFACE itself so the panel floats (gaps on left/top + above the
    // bottom bar), instead of stretching edge-to-edge. QMargins(left, top, right, bottom).
    if (auto *qw = qobject_cast<QWindow *>(engine.rootObjects().constFirst())) {
        if (auto *ls = LayerShellQt::Window::get(qw))
            ls->setMargins(QMargins(12, 12, 0, 64));
    }
    return app.exec();
}

#include "main.moc"
