"""
CandyBarV2 — kiosk queue display.

Entry point.  Stripped of all demo-app scaffolding; keeps only what the
single-screen display and its overlays actually need.
"""

import os
import sys
import threading

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface

from FluentUI import FluentUI
from FluentUI.FluLogger import LogSetup, Logger

from mqtt_demo.mqtt_client import MQTTClient
from example.helper.NetworkHelper import NetworkHelper
from example.helper.SettingsHelper import SettingsHelper
from example.helper.DisplayPersistence import DisplayPersistence
from example.helper.UsageStats import UsageStats
from example.imports import resource_rc as rc   # compiled QRC bundle

_URI = "example"
_MAJOR = 1
_MINOR = 0


def _start_web_server(mqtt_client: MQTTClient, display_persistence, usage_stats):
    """Start the admin HTTP server in a daemon thread."""
    import admin_web.server as srv
    t = threading.Thread(
        target=srv.run,
        args=(mqtt_client, display_persistence, usage_stats),
        daemon=True,
    )
    t.start()


def main():
    # ── Qt / OpenGL setup ────────────────────────────────────────────────
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.OpenGL)

    QGuiApplication.setOrganizationName("CandyBarV2")
    QGuiApplication.setOrganizationDomain("candybar.local")
    QGuiApplication.setApplicationName("CandyBarV2")
    QGuiApplication.setApplicationDisplayName("CandyBarV2")

    LogSetup("candybar")
    Logger().debug(f"Loading resource bundle: {rc.__name__}")

    app = QGuiApplication(sys.argv)

    # ── Register tabular-figures font (DM Mono) ──────────────────────────
    # Font files are bundled in the QRC under example/res/font/
    QFontDatabase.addApplicationFont(":/example/res/font/DMMono-Regular.ttf")
    QFontDatabase.addApplicationFont(":/example/res/font/DMMono-Medium.ttf")

    # ── QML engine ───────────────────────────────────────────────────────
    engine = QQmlApplicationEngine()
    FluentUI.registerTypes(engine)

    # ── Singletons and context properties ───────────────────────────────
    settings        = SettingsHelper()
    persistence     = DisplayPersistence()
    usage_stats     = UsageStats()
    network_helper  = NetworkHelper()
    mqtt_client     = MQTTClient()

    ctx = engine.rootContext()
    ctx.setContextProperty("SettingsHelper",    settings)
    ctx.setContextProperty("DisplayPersistence", persistence)
    ctx.setContextProperty("UsageStats",        usage_stats)
    ctx.setContextProperty("NetworkHelper",     network_helper)
    ctx.setContextProperty("MqttClient",        mqtt_client)

    # ── Start MQTT (non-blocking daemon thread) ──────────────────────────
    mqtt_client.connect_broker()

    # ── Start web server (daemon thread) ─────────────────────────────────
    _start_web_server(mqtt_client, persistence, usage_stats)

    # ── Load root QML ────────────────────────────────────────────────────
    engine.load(QUrl("qrc:/example/qml/App.qml"))
    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
