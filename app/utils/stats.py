
"""
UsageStats — tracks uptime, session count, restart time, number changes.
"""
import os
import time

from PySide6.QtCore import QObject, QSettings, Slot
from PySide6.QtGui import QGuiApplication

from app.utils.logger import get_logger
from app.utils.common import get_app_data_dir

logger = get_logger()

# Simple singleton pattern
_stats_instance = None

def get_stats_instance():
    global _stats_instance
    if _stats_instance is None:
        _stats_instance = UsageStats()
    return _stats_instance

class UsageStats(QObject):
    def __init__(self):
        super().__init__(QGuiApplication.instance())
        ini_path = os.path.join(get_app_data_dir(), "candybar_stats.ini")
        self._s = QSettings(ini_path, QSettings.Format.IniFormat)
        self._start_time = time.time()

        sessions = int(self._s.value("sessionCount", 0) or 0)
        self._s.setValue("sessionCount", sessions + 1)
        self._s.setValue("lastRestartTs", int(self._start_time))
        self._s.sync()
        logger.info(f"Usage stats initialized (session {sessions + 1})")

    def _load_int(self, key: int, default: int = 0) -> int:
        return int(self._s.value(key, default) or default)

    @Slot()
    def record_number_change(self) -> None:
        count = self._load_int("numberChangeCount")
        self._s.setValue("numberChangeCount", count + 1)
        self._s.sync()
        logger.debug(f"Number change recorded: {count + 1}")

    @Slot()
    def reset_stats(self) -> None:
        self._s.setValue("numberChangeCount", 0)
        self._s.sync()
        logger.info("Usage stats reset")

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
