
"""
DisplayStorage — saves/loads display state to disk.
"""
import atexit
import os
import shutil
import threading

from PySide6.QtCore import QObject, Slot, QSettings
from PySide6.QtGui import QGuiApplication

from app.utils.logger import get_logger
from app.utils.paths import get_app_data_dir

logger = get_logger()

# Simple singleton pattern
_storage_instance = None

def get_storage_instance():
    global _storage_instance
    if _storage_instance is None:
        _storage_instance = DisplayStorage()
    return _storage_instance

class DisplayStorage(QObject):
    def __init__(self):
        super().__init__(QGuiApplication.instance())
        self._ini_path = os.path.join(get_app_data_dir(), "candybar_display.ini")
        self._pending_values = {}
        self._pending_lock = threading.Lock()
        self._flush_timer = None
        self._flush_delay_seconds = 0.3
        logger.info(f"Display persistence initialized at {self._ini_path}")
        atexit.register(self.flush_now)
        app = QGuiApplication.instance()
        if app is not None:
            try:
                app.aboutToQuit.connect(self.flush_now)
            except Exception:
                pass

    def _schedule_flush_locked(self):
        if self._flush_timer is not None:
            self._flush_timer.cancel()
        timer = threading.Timer(self._flush_delay_seconds, self.flush_now)
        timer.daemon = True
        self._flush_timer = timer
        timer.start()

    def _take_pending_snapshot(self):
        with self._pending_lock:
            if self._flush_timer is not None:
                self._flush_timer.cancel()
                self._flush_timer = None
            if not self._pending_values:
                return None
            snapshot = dict(self._pending_values)
            self._pending_values.clear()
            return snapshot

    def _safe_default(self, value, default):
        if value is None or value == "":
            return default
        return value

    @Slot(str, 'QVariant')
    def save(self, key: str, value) -> None:
        try:
            with self._pending_lock:
                self._pending_values[key] = value
                self._schedule_flush_locked()
            logger.debug(f"Saved setting: {key} = {value}")
        except Exception as e:
            logger.error(f"Failed to queue save for {key}: {e}", exc_info=True)

    @Slot(str, 'QVariant', result='QVariant')
    def load(self, key: str, default=None):
        try:
            with self._pending_lock:
                if key in self._pending_values:
                    return self._safe_default(self._pending_values[key], default)
            
            # Check if INI file exists and is readable
            if os.path.exists(self._ini_path):
                if not os.access(self._ini_path, os.R_OK):
                    logger.warning(f"INI file exists but is not readable: {self._ini_path}, using default for {key}")
                    return default
            else:
                # File doesn't exist yet - this is normal for fresh installs
                logger.debug(f"INI file does not exist yet: {self._ini_path}, using default for {key}")
                return default
            
            s = QSettings(self._ini_path, QSettings.Format.IniFormat)
            v = s.value(key)
            return self._safe_default(v, default)
        except Exception as e:
            logger.error(f"Failed to load {key} from {self._ini_path}: {e}, using default", exc_info=True)
            return default

    @Slot()
    def flush_now(self) -> None:
        pending = self._take_pending_snapshot()
        if not pending:
            return
        try:
            os.makedirs(os.path.dirname(self._ini_path), exist_ok=True)
            tmp_path = self._ini_path + ".tmp"
            s = QSettings(tmp_path, QSettings.Format.IniFormat)
            for key, value in pending.items():
                s.setValue(key, value)
            s.sync()
            os.replace(tmp_path, self._ini_path)
        except Exception as e:
            logger.error(f"Failed to flush display settings: {e}", exc_info=True)
            with self._pending_lock:
                self._pending_values.update(pending)
                if self._flush_timer is None:
                    self._schedule_flush_locked()

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
        return str(self.load("currentNumber", "00"))

    def get_category(self) -> str:
        return str(self.load("category", "pizza"))

    def get_category_display_name(self) -> str:
        return str(self.load("categoryDisplayName", "pizza"))

    @Slot(result='QVariantList')
    def get_next_up(self) -> list:
        raw = self.load("nextUp", "")
        if not raw:
            return []
        return [x.strip() for x in str(raw).split(",") if x.strip()]

    def get_layout(self) -> str:
        layout = str(self.load("layoutType", "Centered"))
        # Handle legacy "Split" value - map to "Split1"
        if layout == "Split":
            return "Split1"
        # Validate against allowed values
        if layout not in ["Split1", "Split2", "Centered"]:
            return "Centered"
        return layout

    def get_accent(self) -> str:
        return str(self.load("accentColor", "#FFB84D"))

    def get_banner(self) -> str:
        return str(self.load("bannerText", "Welcome — please wait for your number to be called"))

    def get_facility(self) -> str:
        return str(self.load("facilityName", "CandyBar Service Centre"))

    def _get_bounded_int(self, key: str, lo: int, hi: int, default: int) -> int:
        """Shared body for get_font_size()/get_logo_size(), which used to
        each hand-roll this same "parse int, clamp to [lo,hi], else
        default" logic with their own field-specific bounds."""
        v = self.load(key, default)
        try:
            val = int(v)
            return val if lo <= val <= hi else default
        except (TypeError, ValueError):
            return default

    def get_font_size(self) -> int:
        return self._get_bounded_int("fontSize", 120, 800, 120)

    def get_logo_size(self) -> int:
        return self._get_bounded_int("logoSize", 24, 120, 48)

    def get_text_size(self, key: str, default: int) -> int:
        """NOT folded into _get_bounded_int on purpose: this always uses a
        flat [10, 200] range for every font-size field regardless of that
        field's own write-time bound in DisplayState.qml (e.g.
        categoryFontSize is clamped to [20, 130] on write but this accepts
        up to 200 when reading it back for /api/state). That's a real
        cross-layer inconsistency, not an oversight — left exactly as it
        was rather than silently narrowed, since narrowing it changes what
        /api/state reports without anyone having decided that's correct."""
        v = self.load(key, default)
        try:
            val = int(v)
            return val if 10 <= val <= 200 else default
        except (TypeError, ValueError):
            return default

    def reset_all(self) -> None:
        """Reset all display settings to defaults."""
        logger.info("Resetting all display settings")
        try:
            with self._pending_lock:
                self._pending_values.clear()
                if self._flush_timer is not None:
                    self._flush_timer.cancel()
                    self._flush_timer = None
            s = QSettings(self._ini_path, QSettings.Format.IniFormat)
            s.clear()
            s.sync()
            logger.info("All display settings cleared")
        except Exception as e:
            logger.error(f"Failed to reset display settings: {e}", exc_info=True)
