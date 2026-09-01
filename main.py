
"""
CandyBarV2 — kiosk queue display entry point.
"""
import os
import sys
import threading
import pathlib
import shutil

from PySide6.QtCore import QUrl, QFile, QStandardPaths
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface

# FluentUI removed for performance optimization on Raspberry Pi
# from fluentui import FluentUI

from app.mqtt.mqtt_client import MQTTClient
from app.utils.network_info import NetworkHelper
from app.settings.storage import DisplayStorage
from app.utils.stats import UsageStats
from app.audio.audio_engine import AudioEngine
from app.display.font_manager import FontManager
import resources.qrc.resource_rc as rc
from app.utils.logger import setup_logger, get_logger


def _safe_copy_file(src: pathlib.Path, dest: pathlib.Path) -> None:
    """Copies src to dest atomically and verifies the copy."""
    logger = get_logger()
    if not src.exists():
        logger.error(f"Source file does not exist: {src}")
        return

    src_size = src.stat().st_size
    if src_size == 0:
        logger.error(f"Source file is empty: {src}")
        return

    dest.parent.mkdir(parents=True, exist_ok=True)
    
    # We copy to a temporary file first
    temp_dest = dest.with_name(dest.name + ".tmp")
    try:
        shutil.copy2(src, temp_dest)
        
        # Verify the temp file size
        if not temp_dest.exists():
            raise FileNotFoundError(f"Temporary file was not created: {temp_dest}")
        
        temp_size = temp_dest.stat().st_size
        if temp_size != src_size:
            raise ValueError(f"Size mismatch after copy. Source: {src_size} bytes, Temp: {temp_size} bytes")
        
        # Atomic rename
        os.replace(temp_dest, dest)
        logger.debug(f"Successfully copied: {src} -> {dest} ({src_size} bytes)")
    except Exception as e:
        logger.error(f"Failed to copy {src} to {dest}: {e}", exc_info=True)
        # Clean up temp file if it exists
        if temp_dest.exists():
            try:
                temp_dest.unlink()
            except Exception as cleanup_err:
                logger.error(f"Failed to clean up temporary file {temp_dest}: {cleanup_err}")
        # Clean up empty/corrupt destination file if it was created
        if dest.exists() and dest.stat().st_size == 0:
            try:
                dest.unlink()
            except Exception as cleanup_err:
                logger.error(f"Failed to clean up empty destination file {dest}: {cleanup_err}")


def _copy_tree_preserve_existing(src: pathlib.Path, dest: pathlib.Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for item in src.iterdir():
        dest_item = dest / item.name
        if item.is_dir():
            if dest_item.exists() and not dest_item.is_dir():
                dest_item.unlink()
            _copy_tree_preserve_existing(item, dest_item)
        else:
            # Only copy if destination doesn't exist, is empty, size is mismatched, or source is newer
            dest_exists = dest_item.exists()
            dest_empty = dest_exists and dest_item.stat().st_size == 0
            dest_size_mismatch = dest_exists and dest_item.stat().st_size != item.stat().st_size
            if not dest_exists or dest_empty or dest_size_mismatch or item.stat().st_mtime > dest_item.stat().st_mtime:
                _safe_copy_file(item, dest_item)


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


def _copy_audio_assets_to_data_dir(data_dir: str, copy_completed_event: threading.Event) -> None:
    logger = get_logger()
    try:
        project_root = pathlib.Path(__file__).parent
        resources_audio = project_root / "resources" / "audio"
        data_audio = pathlib.Path(data_dir) / "audio"
        if resources_audio.exists():
            data_audio.mkdir(parents=True, exist_ok=True)
            for item in resources_audio.iterdir():
                dest_item = data_audio / item.name
                if item.is_dir():
                    _copy_tree_preserve_existing(item, dest_item)
                    logger.debug(f"Seeded audio folder: {item.name} → {dest_item}")
                else:
                    # Only copy if destination doesn't exist, is empty, size is mismatched, or source is newer
                    dest_exists = dest_item.exists()
                    dest_empty = dest_exists and dest_item.stat().st_size == 0
                    dest_size_mismatch = dest_exists and dest_item.stat().st_size != item.stat().st_size
                    if not dest_exists or dest_empty or dest_size_mismatch or item.stat().st_mtime > dest_item.stat().st_mtime:
                        _safe_copy_file(item, dest_item)

        chime_src = project_root / "Announcement sound effect - Sound Effects (128k).mp3"
        chime_dest = data_audio / "announcement_chime.mp3"
        if chime_src.exists():
            dest_exists = chime_dest.exists()
            dest_empty = dest_exists and chime_dest.stat().st_size == 0
            dest_size_mismatch = dest_exists and chime_dest.stat().st_size != chime_src.stat().st_size
            if not dest_exists or dest_empty or dest_size_mismatch or chime_src.stat().st_mtime > chime_dest.stat().st_mtime:
                _safe_copy_file(chime_src, chime_dest)
                logger.debug(f"Seeded announcement chime: {chime_src} → {chime_dest}")
    except Exception as e:
        logger.error(f"Error during audio assets copy: {e}", exc_info=True)
    finally:
        copy_completed_event.set()



def _start_web_server(mqtt_client, display_persistence, usage_stats, font_manager, audio_engine):
    logger = get_logger()
    try:
        from app.web import web_server as srv
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
    HEADLESS = os.environ.get("CANDYBAR_HEADLESS", "").lower() in ("1", "true", "yes")

    # Set Qt application metadata BEFORE any QSettings usage to ensure consistent storage paths
    # This must be done regardless of HEADLESS mode to guarantee canonical storage location
    QGuiApplication.setOrganizationName("CandyBarV2")
    QGuiApplication.setOrganizationDomain("candybar.local")
    QGuiApplication.setApplicationName("CandyBarV2")
    QGuiApplication.setApplicationDisplayName("CandyBarV2")

    if not HEADLESS:
        os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
        # Respect QT_QUICK_BACKEND=software set by ./run for Pi Zero 2 W —
        # only force the OpenGL RHI graphics API when NOT using the software backend.
        if os.environ.get("QT_QUICK_BACKEND") != "software":
            QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.OpenGL)

    setup_logger()
    logger = get_logger()
    logger.info("Starting CandyBarV2" + (" (headless mode)" if HEADLESS else ""))
    logger.debug(f"Loading resource bundle: {rc.__name__}")

    if not HEADLESS:
        app = QGuiApplication(sys.argv)

    # Load custom fonts (only in GUI mode)
    if not HEADLESS:
        font_ids = []
        project_root = pathlib.Path(__file__).resolve().parent
        fonts = [
            ":/app/res/font/Barriecito-Regular.ttf",
            ":/app/res/font/DTGetaiGroteskDisplay-Black.otf",
            ":/app/res/font/Gluten-Regular.ttf",
            ":/app/res/font/LCMogi-A.otf",
            ":/app/res/font/Manosque-Regular.otf",
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

    if not HEADLESS:
        engine = QQmlApplicationEngine()
        # FluentUI removed for performance optimization on Raspberry Pi
        # FluentUI.registerTypes(engine)

    try:
        storage = DisplayStorage()
        usage_stats = UsageStats()
        network_helper = NetworkHelper()
        mqtt_client = MQTTClient()
        audio_engine = AudioEngine()
        font_manager = FontManager()

        audio_engine.set_data_dir(os.path.join(_data_dir, "audio"))

        # Copy audio assets in background thread to avoid blocking startup
        t = threading.Thread(
            target=_copy_audio_assets_to_data_dir,
            args=(_data_dir, audio_engine.copy_completed),
            daemon=True,
        )
        t.start()
        logger.info("Audio asset copy started in background")

        font_manager.load_saved_fonts(_data_dir)

        if not HEADLESS:
            ctx = engine.rootContext()
            ctx.setContextProperty("DisplayStorage", storage)
            ctx.setContextProperty("UsageStats", usage_stats)
            ctx.setContextProperty("NetworkHelper", network_helper)
            ctx.setContextProperty("MqttClient", mqtt_client)
            ctx.setContextProperty("AudioEngine", audio_engine)
            ctx.setContextProperty("FontManager", font_manager)

        mqtt_client.connect_broker()
        _start_web_server(mqtt_client, storage, usage_stats, font_manager, audio_engine)

        if not HEADLESS:
            engine.load(QUrl("qrc:/app/qml/App.qml"))
            if not engine.rootObjects():
                raise RuntimeError("QML root objects did not load")

            logger.info("Application started, entering event loop")
            sys.exit(app.exec())
        else:
            logger.info("Headless mode: web server and MQTT running, keeping process alive")
            # Keep the process alive since web server runs in a daemon thread
            import time
            while True:
                time.sleep(1)
    except Exception as e:
        logger.critical(f"Startup failed: {e}", exc_info=True)
        if not HEADLESS:
            sys.stderr.write(f"[startup] CandyBarV2 failed to boot: {e}\n")
        raise


if __name__ == "__main__":
    main()
