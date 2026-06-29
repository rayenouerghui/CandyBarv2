"""
DisplayPersistence — saves/loads all display state to disk immediately on
every change.  A power loss must not reset customization.

Storage: QSettings INI at AppLocalDataLocation/candybar_display.ini
Logo:    AppLocalDataLocation/logo.<ext>  (copied on upload, path stored)
"""

import os
import shutil

from PySide6.QtCore import QObject, Slot, QStandardPaths, QSettings
from PySide6.QtGui import QGuiApplication

from FluentUI.Singleton import Singleton

_DATA_DIR = QStandardPaths.writableLocation(
    QStandardPaths.StandardLocation.AppLocalDataLocation
)


def _data_dir() -> str:
    os.makedirs(_DATA_DIR, exist_ok=True)
    return _DATA_DIR


@Singleton
class DisplayPersistence(QObject):
    def __init__(self):
        super().__init__(QGuiApplication.instance())
        ini_path = os.path.join(_data_dir(), "candybar_display.ini")
        self._s = QSettings(ini_path, QSettings.Format.IniFormat)

    # ── generic helpers ────────────────────────────────────────────────
    def save(self, key: str, value) -> None:
        self._s.setValue(key, value)
        self._s.sync()

    def load(self, key: str, default=None):
        v = self._s.value(key)
        return v if v is not None else default

    # ── logo file handling ─────────────────────────────────────────────
    @Slot(str, result=str)
    def save_logo(self, src_path: str) -> str:
        """Copy uploaded logo to data dir, return the new absolute path."""
        ext = os.path.splitext(src_path)[1].lower() or ".png"
        dest = os.path.join(_data_dir(), f"logo{ext}")
        shutil.copy2(src_path, dest)
        self.save("logoPath", dest)
        return dest

    def logo_path(self) -> str:
        return self.load("logoPath", "")

    # ── PIN ────────────────────────────────────────────────────────────
    def get_pin(self) -> str:
        return str(self.load("adminPin", "1234"))

    def set_pin(self, pin: str) -> None:
        self.save("adminPin", pin)

    # ── convenience wrappers for each display property ─────────────────
    def get_current_number(self) -> str:
        return str(self.load("currentNumber", "001"))

    def get_next_up(self) -> list:
        raw = self.load("nextUp", "")
        if not raw:
            return []
        return [x.strip() for x in str(raw).split(",") if x.strip()]

    def get_layout(self) -> str:
        return str(self.load("layoutType", "Classic"))

    def get_accent(self) -> str:
        return str(self.load("accentColor", "#0078D4"))

    def get_banner(self) -> str:
        return str(self.load("bannerText", "Welcome — please wait for your number to be called"))

    def get_facility(self) -> str:
        return str(self.load("facilityName", "CandyBar Service Centre"))

    def get_font_size(self) -> int:
        return int(self.load("fontSize", 72))
