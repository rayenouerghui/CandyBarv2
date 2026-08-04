
"""
DisplayPersistence — saves/loads display state to disk.
"""
import os
import shutil

from PySide6.QtCore import QObject, Slot, QSettings
from PySide6.QtGui import QGuiApplication

from fluentui.Singleton import Singleton
from app.utils.logger import get_logger
from app.utils.common import get_app_data_dir

logger = get_logger()

@Singleton
class DisplayPersistence(QObject):
    def __init__(self):
        super().__init__(QGuiApplication.instance())
        self._ini_path = os.path.join(get_app_data_dir(), "candybar_display.ini")
        logger.info(f"Display persistence initialized at {self._ini_path}")

    @Slot(str, 'QVariant')
    def save(self, key: str, value) -> None:
        try:
            s = QSettings(self._ini_path, QSettings.Format.IniFormat)
            s.setValue(key, value)
            s.sync()
            logger.debug(f"Saved setting: {key} = {value}")
        except Exception as e:
            logger.error(f"Failed to save {key}: {e}", exc_info=True)

    @Slot(str, 'QVariant', result='QVariant')
    def load(self, key: str, default=None):
        try:
            s = QSettings(self._ini_path, QSettings.Format.IniFormat)
            v = s.value(key)
            return v if v is not None else default
        except Exception as e:
            logger.error(f"Failed to load {key}: {e}", exc_info=True)
            return default

    @Slot(str, result=str)
    def save_logo(self, src_path: str) -> str:
        try:
            ext = os.path.splitext(src_path)[1].lower() or ".png"
            dest = os.path.join(get_app_data_dir(), f"logo{ext}")
            shutil.copy2(src_path, dest)
            self.save("logoPath", dest)
            logger.info(f"Saved logo to {dest}")
            return dest
        except Exception as e:
            logger.error(f"Failed to save logo: {e}", exc_info=True)
            return ""

    @Slot(result=str)
    def logo_path(self) -> str:
        rel_path = self.load("logoPath", "")
        if not rel_path:
            return ""
        # If it's already an absolute path, return it
        if os.path.isabs(rel_path):
            return rel_path
        # Convert relative path to absolute path using data directory
        data_dir = get_app_data_dir()
        abs_path = os.path.join(data_dir, rel_path)
        return abs_path if os.path.isfile(abs_path) else ""

    def background_path(self) -> str:
        rel_path = self.load("backgroundImage", "")
        if not rel_path:
            return ""
        # If it's a qrc path, return as-is
        if rel_path.startswith("qrc:"):
            return rel_path
        # If it's already an absolute path, return it
        if os.path.isabs(rel_path):
            return rel_path if os.path.isfile(rel_path) else rel_path
        # Convert relative path to absolute path using data directory
        data_dir = get_app_data_dir()
        abs_path = os.path.join(data_dir, rel_path)
        return abs_path if os.path.isfile(abs_path) else rel_path

    @Slot(result=str)
    def get_pin(self) -> str:
        return str(self.load("adminPin", "1234"))

    @Slot(str)
    def set_pin(self, pin: str) -> None:
        self.save("adminPin", pin)

    def get_current_number(self) -> str:
        return str(self.load("currentNumber", "001"))

    @Slot(result='QVariantList')
    def get_next_up(self) -> list:
        raw = self.load("nextUp", "")
        if not raw:
            return []
        return [x.strip() for x in str(raw).split(",") if x.strip()]

    def get_layout(self) -> str:
        return str(self.load("layoutType", "Centered"))

    def get_accent(self) -> str:
        return str(self.load("accentColor", "#FFB84D"))

    def get_banner(self) -> str:
        return str(self.load("bannerText", "Welcome — please wait for your number to be called"))

    def get_facility(self) -> str:
        return str(self.load("facilityName", "CandyBar Service Centre"))

    def get_font_size(self) -> int:
        v = self.load("fontSize", 96)
        try:
            fs = int(v)
            return fs if 48 <= fs <= 200 else 96
        except (TypeError, ValueError):
            return 96

    def get_logo_size(self) -> int:
        v = self.load("logoSize", 48)
        try:
            ls = int(v)
            return ls if 24 <= ls <= 120 else 48
        except (TypeError, ValueError):
            return 48

    def get_text_size(self, key: str, default: int) -> int:
        v = self.load(key, default)
        try:
            val = int(v)
            return val if 120 <= val <= 800 else default
        except (TypeError, ValueError):
            return default

    def get_display_language(self) -> str:
        v = str(self.load("displayLanguage", "en"))
        return v if v in ("en", "fr") else "en"

    def reset_all(self) -> None:
        """Reset all display settings to defaults."""
        logger.info("Resetting all display settings")
        try:
            s = QSettings(self._ini_path, QSettings.Format.IniFormat)
            s.clear()
            s.sync()
            logger.info("All display settings cleared")
        except Exception as e:
            logger.error(f"Failed to reset display settings: {e}", exc_info=True)
