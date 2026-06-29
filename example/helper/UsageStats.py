"""
UsageStats — tracks uptime, session count, restart time, number-change count.
Persisted to AppLocalDataLocation/candybar_stats.ini on every write.
Exposed as a plain Python object; stats are read by the HTTP server endpoint.
"""

import os
import time

from PySide6.QtCore import QObject, QStandardPaths, QSettings, Slot
from PySide6.QtGui import QGuiApplication

from FluentUI.Singleton import Singleton

_DATA_DIR = QStandardPaths.writableLocation(
    QStandardPaths.StandardLocation.AppLocalDataLocation
)


def _data_dir() -> str:
    os.makedirs(_DATA_DIR, exist_ok=True)
    return _DATA_DIR


@Singleton
class UsageStats(QObject):
    def __init__(self):
        super().__init__(QGuiApplication.instance())
        ini_path = os.path.join(_data_dir(), "candybar_stats.ini")
        self._s = QSettings(ini_path, QSettings.Format.IniFormat)
        self._start_time = time.time()

        # Increment session count on every boot
        sessions = int(self._s.value("sessionCount", 0) or 0)
        self._s.setValue("sessionCount", sessions + 1)
        self._s.setValue("lastRestartTs", int(self._start_time))
        self._s.sync()

    def _load_int(self, key: int, default: int = 0) -> int:
        return int(self._s.value(key, default) or default)

    @Slot()
    def record_number_change(self) -> None:
        count = self._load_int("numberChangeCount")
        self._s.setValue("numberChangeCount", count + 1)
        self._s.sync()

    def as_dict(self) -> dict:
        uptime_seconds = int(time.time() - self._start_time)
        h = uptime_seconds // 3600
        m = (uptime_seconds % 3600) // 60
        s = uptime_seconds % 60
        return {
            "uptime": f"{h:02d}:{m:02d}:{s:02d}",
            "uptime_seconds": uptime_seconds,
            "session_count": self._load_int("sessionCount"),
            "last_restart_ts": int(self._s.value("lastRestartTs", 0) or 0),
            "number_change_count": self._load_int("numberChangeCount"),
        }
