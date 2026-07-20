
"""
CandyBarV2 — kiosk queue display entry point.
"""
import os
import sys
import threading
import pathlib

from PySide6.QtCore import QUrl, QFile, QStandardPaths
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface

from fluentui import FluentUI

from src.mqtt.client import MQTTClient
from src.utils.network_helper import NetworkHelper
from src.config.persistence import DisplayPersistence
from src.utils.stats import UsageStats
from src.audio.engine import AudioEngine
from src.display.font_manager import FontManager
from app.imports import resource_rc as rc
from src.logging import setup_logger, get_logger


def _copy_static_assets_to_data_dir(data_dir: str) -> None:
    logger = get_logger()
    pathlib.Path(data_dir).mkdir(parents=True, exist_ok=True)
    assets = [
        (":/app/res/image/noise_texture.png", "noise_texture.png"),
    ]
    for qrc_path, filename in assets:
        dest = os.path.join(data_dir, filename)
        if not os.path.exists(dest):
            qf = QFile(qrc_path)
            if qf.open(QFile.OpenModeFlag.ReadOnly):
                with open(dest, "wb") as f:
                    f.write(qf.readAll().data())
                qf.close()
                logger.debug(f"Seeded {filename} → {dest}")
    # Copy pre-generated audio from resources to data directory
    project_root = pathlib.Path(__file__).parent
    resources_audio = project_root / "resources" / "audio"
    data_audio = pathlib.Path(data_dir) / "audio"
    if resources_audio.exists():
        data_audio.mkdir(parents=True, exist_ok=True)
        import shutil
        for item in resources_audio.iterdir():
            dest_item = data_audio / item.name
            if item.is_dir():
                if item.name in ("en", "fr", "ar"):
                    # For language directories: only copy numbers/ subdir, preserve category/
                    dest_item.mkdir(parents=True, exist_ok=True)
                    src_numbers = item / "numbers"
                    dest_numbers = dest_item / "numbers"
                    if src_numbers.exists():
                        if dest_numbers.exists():
                            shutil.rmtree(dest_numbers)
                        shutil.copytree(src_numbers, dest_numbers)
                        logger.debug(f"Seeded numbers folder: {src_numbers} → {dest_numbers}")
                else:
                    # For other directories, copy only if not exists
                    if not dest_item.exists():
                        shutil.copytree(item, dest_item)
                        logger.debug(f"Seeded audio folder: {item.name} → {dest_item}")
            else:
                # Copy files only if not exists
                if not dest_item.exists():
                    shutil.copy2(item, dest_item)

    # Copy custom chime sound effect from project root to audio data directory
    chime_src = project_root / "Announcement sound effect - Sound Effects (128k).mp3"
    chime_dest = data_audio / "announcement_chime.mp3"
    if chime_src.exists():
        data_audio.mkdir(parents=True, exist_ok=True)
        import shutil
        shutil.copy2(chime_src, chime_dest)
        logger.debug(f"Seeded announcement chime: {chime_src} → {chime_dest}")



def _start_web_server(mqtt_client, display_persistence, usage_stats, font_manager, audio_engine):
    logger = get_logger()
    try:
        import web.server as srv
        t = threading.Thread(
            target=srv.run,
            args=(mqtt_client, display_persistence, usage_stats, font_manager, audio_engine, sys.argv),
            daemon=True,
        )
        t.start()
        logger.info("Web server started")
    except Exception as e:
        logger.error(f"Failed to start web server: {e}", exc_info=True)


def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.OpenGL)

    QGuiApplication.setOrganizationName("CandyBarV2")
    QGuiApplication.setOrganizationDomain("candybar.local")
    QGuiApplication.setApplicationName("CandyBarV2")
    QGuiApplication.setApplicationDisplayName("CandyBarV2")

    setup_logger()
    logger = get_logger()
    logger.info("Starting CandyBarV2")
    logger.debug(f"Loading resource bundle: {rc.__name__}")

    app = QGuiApplication(sys.argv)

    # Load custom fonts
    font_ids = []
    fonts = [
        ":/app/res/font/Barriecito-Regular.ttf",
        ":/app/res/font/DTGetaiGroteskDisplay-Black.otf",
        ":/app/res/font/Gluten-Regular.ttf",
        ":/app/res/font/LCMogi-A.otf",
        ":/app/res/font/Manosque-Regular.otf"
    ]
    for font_path in fonts:
        fid = QFontDatabase.addApplicationFont(font_path)
        font_ids.append(fid)
        if fid == -1:
            logger.warning(f"Warning: Failed to load font {font_path}")

    _data_dir = QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.AppLocalDataLocation
    )
    _copy_static_assets_to_data_dir(_data_dir)

    engine = QQmlApplicationEngine()
    FluentUI.registerTypes(engine)

    persistence = DisplayPersistence()
    usage_stats = UsageStats()
    network_helper = NetworkHelper()
    mqtt_client = MQTTClient()
    audio_engine = AudioEngine()
    font_manager = FontManager()

    audio_engine.set_data_dir(os.path.join(_data_dir, "audio"))
    font_manager.load_saved_fonts(_data_dir)

    ctx = engine.rootContext()
    ctx.setContextProperty("DisplayPersistence", persistence)
    ctx.setContextProperty("UsageStats", usage_stats)
    ctx.setContextProperty("NetworkHelper", network_helper)
    ctx.setContextProperty("MqttClient", mqtt_client)
    ctx.setContextProperty("AudioEngine", audio_engine)
    ctx.setContextProperty("FontManager", font_manager)

    mqtt_client.connect_broker()
    _start_web_server(mqtt_client, persistence, usage_stats, font_manager, audio_engine)

    engine.load(QUrl("qrc:/app/qml/App.qml"))
    if not engine.rootObjects():
        logger.critical("Failed to load QML application")
        sys.exit(-1)

    logger.info("Application started, entering event loop")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
