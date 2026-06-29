"""
SettingsHelper — thin QSettings wrapper for app-level preferences.
Display state persistence is handled separately by DisplayPersistence.
"""

from PySide6.QtCore import QObject, Slot, QStandardPaths, QSettings
from PySide6.QtGui import QGuiApplication

from FluentUI.Singleton import Singleton


@Singleton
class SettingsHelper(QObject):
    def __init__(self):
        super().__init__(QGuiApplication.instance())
        from PySide6.QtCore import QStandardPaths
        ini_path = (
            QStandardPaths.writableLocation(QStandardPaths.StandardLocation.AppLocalDataLocation)
            + "/candybar_app.ini"
        )
        self._s = QSettings(ini_path, QSettings.Format.IniFormat)

    def _save(self, key, val):
        self._s.setValue(key, val)
        self._s.sync()

    def _get(self, key, default):
        v = self._s.value(key)
        return v if v is not None else default

    @Slot(result=int)
    def getDarkMode(self):
        return int(self._get("darkMode", 2))   # default: Dark

    @Slot(int)
    def saveDarkMode(self, darkMode: int):
        self._save("darkMode", darkMode)

    @Slot(result=bool)
    def getUseSystemAppBar(self):
        return False   # kiosk: never use system app bar

    @Slot(result=str)
    def getLanguage(self):
        return str(self._get("language", "en_US"))

    @Slot(str)
    def saveLanguage(self, language: str):
        self._save("language", language)
