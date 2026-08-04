
"""
FontManager — runtime TTF/OTF registration via QFontDatabase.
"""
import os
import re
import shutil

from PySide6.QtCore import QObject, Slot, Signal, Property
from PySide6.QtGui import QFontDatabase, QGuiApplication

from fluentui.Singleton import Singleton
from app.utils.logger import get_logger
from app.utils.common import get_app_data_dir

logger = get_logger()


def _safe_filename(name: str) -> str:
    return re.sub(r"[^\w\-]", "_", name.lower())[:64]


@Singleton
class FontManager(QObject):
    fontsChanged = Signal()

    def __init__(self):
        super().__init__(QGuiApplication.instance())
        self._fonts: list[dict] = []
        self._selected = ""

    @Property(str)
    def selectedFont(self) -> str:
        return self._selected

    @Property(list, notify=fontsChanged)
    def fonts(self) -> list:
        return self._fonts

    @Slot(str, result=str)
    def registerFont(self, src_path: str) -> str:
        if not os.path.isfile(src_path):
            logger.warning(f"Font file not found: {src_path}")
            return ""
        ext = os.path.splitext(src_path)[1].lower()
        if ext not in (".ttf", ".otf"):
            logger.warning(f"Unsupported font format: {ext}")
            return ""

        data_dir = get_app_data_dir()
        fonts_dir = os.path.join(data_dir, "fonts")
        os.makedirs(fonts_dir, exist_ok=True)

        try:
            fid = QFontDatabase.addApplicationFont(src_path)
            if fid == -1:
                logger.error("Failed to add application font")
                return ""
            families = QFontDatabase.applicationFontFamilies(fid)
            if not families:
                logger.warning("No font families found in font file")
                return ""
            family = families[0]
            dest = os.path.join(fonts_dir, f"{_safe_filename(family)}{ext}")
            shutil.copy2(src_path, dest)
            logger.info(f"Registered font: {family} at {dest}")
            self._refresh_list(fonts_dir)
            return family
        except Exception as e:
            logger.error(f"Failed to register font: {e}", exc_info=True)
            return ""

    @Slot(str)
    def selectFont(self, family: str):
        self._selected = family
        self.fontsChanged.emit()

    @Slot(result=list)
    def listFonts(self) -> list:
        return self._fonts

    def load_saved_fonts(self, data_dir: str):
        try:
            fonts_dir = os.path.join(data_dir, "fonts")
            if not os.path.isdir(fonts_dir):
                return
            for fname in os.listdir(fonts_dir):
                if fname.lower().endswith((".ttf", ".otf")):
                    path = os.path.join(fonts_dir, fname)
                    QFontDatabase.addApplicationFont(path)
            self._refresh_list(fonts_dir)
            logger.info("Loaded saved fonts")
        except Exception as e:
            logger.error(f"Failed to load saved fonts: {e}", exc_info=True)

    def _refresh_list(self, fonts_dir: str):
        items = []
        if os.path.isdir(fonts_dir):
            for fname in sorted(os.listdir(fonts_dir)):
                if not fname.lower().endswith((".ttf", ".otf")):
                    continue
                path = os.path.join(fonts_dir, fname)
                fid = QFontDatabase.addApplicationFont(path)
                if fid == -1:
                    continue
                families = QFontDatabase.applicationFontFamilies(fid)
                if families:
                    items.append({"family": families[0], "path": path, "filename": fname})
        self._fonts = items
        self.fontsChanged.emit()
