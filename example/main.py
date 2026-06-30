"""
CandyBarV2 — kiosk queue display.

Entry point. Stripped of all demo-app scaffolding; keeps only what the
single-screen display and its overlays actually need.

Kiosk deployment notes:
  - Run with: python3 -m example.main  (from project root)
  - Working directory: project root (so QRC paths resolve)
  - Log file: ~/.local/share/CandyBarV2/CandyBarV2/candybar.log (via FluLogger)
  - For fullscreen on ARM/Pi: no extra flags needed — App.qml sets
    visibility: Window.FullScreen. If the compositor fights it, add
    QT_QPA_PLATFORM=xcb or QT_QPA_PLATFORM=eglfs to your systemd unit.
  - systemd auto-restart: set Restart=on-failure, RestartSec=3s
  - Recommended .service Environment vars:
      QT_QUICK_CONTROLS_STYLE=Basic
      QT_QPA_PLATFORM=eglfs        (bare-metal ARM, no X11)
      or
      DISPLAY=:0                   (if running under X11/Openbox)
"""

import os
import sys
import threading
import pathlib

from PySide6.QtCore import QUrl, QFile, QStandardPaths
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine
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


def _copy_static_assets_to_data_dir(data_dir: str) -> None:
    """
    Copy static assets from the QRC bundle into the data directory so that
    the HTTP server can serve them under /uploads/.

    Why /uploads/ and not a separate /static/ route?
    The server already has a clean /uploads/<filename> handler that maps to
    UPLOAD_DIR. Adding a second route for a single file would complicate the
    server for no gain. Instead we seed the data dir with the noise texture
    once at startup — it's a 50-100 KB PNG that never changes.

    This is the *only* case where we copy from QRC to disk at runtime.
    The noise texture is referenced in admin.html and public.html as
    /uploads/noise_texture.png, served by the existing /uploads/ route.
    """
    pathlib.Path(data_dir).mkdir(parents=True, exist_ok=True)
    assets = [
        (":/example/res/image/noise_texture.png", "noise_texture.png"),
    ]
    for qrc_path, filename in assets:
        dest = os.path.join(data_dir, filename)
        if not os.path.exists(dest):
            qf = QFile(qrc_path)
            if qf.open(QFile.OpenModeFlag.ReadOnly):
                with open(dest, "wb") as f:
                    f.write(qf.readAll().data())
                qf.close()
                Logger().debug(f"Seeded {filename} → {dest}")
            else:
                Logger().debug(f"Warning: could not open {qrc_path} from QRC")


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
    # DM Mono uses genuine tabular/monospaced figures — every digit 0-9
    # has identical advance width, so the number never shifts horizontally
    # when digits change (e.g. 099 → 100 doesn't cause layout reflow).
    # Font files are bundled in the QRC under example/res/font/.
    # License: SIL Open Font License 1.1 (free for commercial use/embedding).
    _reg = QFontDatabase.addApplicationFont(":/example/res/font/DMMono-Regular.otf")
    _med = QFontDatabase.addApplicationFont(":/example/res/font/DMMono-Medium.otf")
    if _reg == -1 or _med == -1:
        Logger().debug("Warning: DM Mono font not loaded — font files missing from QRC bundle. "
                       "Run: pyside6-rcc example/imports/resource.qrc -o example/imports/resource_rc.py "
                       "after placing DMMono-Regular.otf and DMMono-Medium.otf in "
                       "example/imports/example/res/font/")

    # ── Copy static web assets to data dir (noise texture for /uploads/) ─
    _data_dir = QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.AppLocalDataLocation
    )
    _copy_static_assets_to_data_dir(_data_dir)

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
    ctx.setContextProperty("SettingsHelper",     settings)
    ctx.setContextProperty("DisplayPersistence", persistence)
    ctx.setContextProperty("UsageStats",         usage_stats)
    ctx.setContextProperty("NetworkHelper",      network_helper)
    ctx.setContextProperty("MqttClient",         mqtt_client)

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
