
"""
AudioEngine.py — TTS audio playback engine for CandyBarV2.
Hybrid pre-generation + runtime playback. No live TTS at runtime.
Uses pygame.mixer.music for sequential atom playback (MP3 supported).
"""
import os
import re
import threading
import time
from pathlib import Path
from typing import List

from PySide6.QtCore import QObject, Slot, Property

try:
    import pygame
    import pygame.mixer
except ImportError:
    pygame = None

from src.logging import get_logger

logger = get_logger()


def _slug(name: str) -> str:
    """Normalise a display name to a safe filename slug."""
    return re.sub(r"[^\w\-]", "_", name.lower().strip())[:48]


class AudioEngine(QObject):
    VOLUME_STEPS = [0.0, 0.35, 0.55, 0.75, 1.0]

    def __init__(self, parent=None):
        super().__init__(parent)
        self._initialized = False
        self._muted = False
        self._volume_step = 3  # index into VOLUME_STEPS (default ~0.75)
        self._language = "en"
        self._data_dir = ""
        self._playing = False
        self._stop_flag = False
        self._category_display_name = "Counter A"
        self._tts_enabled = True
        self._category_audio_enabled = True
        self._lock = threading.Lock()
        self._debounce_timer = None
        self._init_mixer()

    def _init_mixer(self):
        if pygame is None:
            logger.warning("pygame not installed — audio disabled")
            return
        try:
            pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
            self._initialized = True
            logger.info("Audio mixer initialized OK")
        except Exception as e:
            logger.error(f"Failed to initialize audio: {e}", exc_info=True)

    @Property(bool)
    def muted(self):
        return self._muted

    @muted.setter
    def muted(self, value):
        self._muted = bool(value)
        if self._initialized:
            if self._muted:
                pygame.mixer.music.set_volume(0.0)
            else:
                pygame.mixer.music.set_volume(self.VOLUME_STEPS[self._volume_step])

    @Property(int)
    def volumeStep(self):
        return self._volume_step

    @volumeStep.setter
    def volumeStep(self, value):
        self._volume_step = max(0, min(len(self.VOLUME_STEPS) - 1, int(value)))
        # Apply volume immediately if playing and not muted
        if self._initialized and not self._muted and pygame.mixer.music.get_busy():
            pygame.mixer.music.set_volume(self.VOLUME_STEPS[self._volume_step])

    @Property(float)
    def volume(self):
        return self.VOLUME_STEPS[self._volume_step]

    @Property(bool)
    def playing(self):
        return self._playing

    @Property(str)
    def language(self):
        return self._language

    @language.setter
    def language(self, value):
        if value in ("en", "fr", "ar"):
            self._language = value

    @Property(bool)
    def ttsEnabled(self):
        return self._tts_enabled

    @ttsEnabled.setter
    def ttsEnabled(self, value):
        self._tts_enabled = bool(value)

    @Property(bool)
    def categoryAudioEnabled(self):
        return self._category_audio_enabled

    @categoryAudioEnabled.setter
    def categoryAudioEnabled(self, value):
        self._category_audio_enabled = bool(value)

    def set_data_dir(self, data_dir: str):
        self._data_dir = data_dir
        logger.info(f"Audio data dir set to: {data_dir}")

    @Slot(str)
    def set_category_display_name(self, name: str):
        clean = (name or "Counter A").strip()
        if self._category_display_name == clean:
            return
        self._category_display_name = clean
        if self._data_dir and clean:
            self._ensure_category_audio(clean)

    def _ensure_category_audio(self, name: str):
        """Generate category MP3s in background if any language is missing."""
        slug = _slug(name)
        missing = [
            lang for lang in ("en", "fr", "ar")
            if not os.path.isfile(os.path.join(self._data_dir, lang, "category", f"{slug}.mp3"))
        ]
        if not missing:
            return
        logger.info(f"Generating category audio for '{name}' (missing: {missing})")
        try:
            from src.audio.category_helper import generate_category_audio
            generate_category_audio(name, self._data_dir)
        except Exception as e:
            logger.error(f"Category audio generation failed: {e}", exc_info=True)

    @Slot(str)
    def announceNumber(self, number: str):
        """Announce: number + [category name] (debounced)."""
        if not self._initialized or self._muted or not self._tts_enabled:
            logger.debug(
                f"Audio blocked — init={self._initialized} muted={self._muted} tts={self._tts_enabled}"
            )
            return

        # Stop any currently playing audio sequence immediately
        self._stop_flag = True

        # Cancel any active debounce timer
        with self._lock:
            if hasattr(self, "_debounce_timer") and self._debounce_timer is not None:
                self._debounce_timer.cancel()
                self._debounce_timer = None

            # Start a new 1.0-second debounce timer
            self._debounce_timer = threading.Timer(1.0, self._debounced_announce, args=(number,))
            self._debounce_timer.start()

    def _debounced_announce(self, number: str):
        with self._lock:
            self._debounce_timer = None

        logger.info(f"Announcing settled number: {number}")
        threading.Thread(
            target=self._play_announcement,
            args=(number,),
            daemon=True,
        ).start()

    @Slot()
    def stop(self):
        self._stop_flag = True
        with self._lock:
            if hasattr(self, "_debounce_timer") and self._debounce_timer is not None:
                self._debounce_timer.cancel()
                self._debounce_timer = None
        if self._initialized:
            try:
                pygame.mixer.music.stop()
            except Exception as e:
                logger.warning(f"Error stopping audio playback: {e}")

    def _play_announcement(self, number: str):
        with self._lock:
            self._stop_flag = False
            self._playing = True
            try:
                files = self._build_sequence(number)
                if not files:
                    logger.warning(f"Empty sequence for number '{number}'")
                    return
                vol = self.VOLUME_STEPS[self._volume_step]
                gap = 0.04
                for rel in files:
                    if self._stop_flag:
                        break
                    full = os.path.join(self._data_dir, rel)
                    if not os.path.isfile(full):
                        logger.warning(f"Missing audio atom: {full}")
                        continue
                    try:
                        pygame.mixer.music.load(full)
                        pygame.mixer.music.set_volume(vol)
                        pygame.mixer.music.play()

                        is_chime = os.path.basename(full) == "announcement_chime.mp3"
                        start_time = time.time()

                        while pygame.mixer.music.get_busy():
                            if self._stop_flag:
                                pygame.mixer.music.stop()
                                return
                            # Play the chime file for only 3 seconds max
                            if is_chime and (time.time() - start_time >= 3.0):
                                pygame.mixer.music.stop()
                                break
                            time.sleep(0.01)
                        time.sleep(gap)
                    except Exception as exc:
                        logger.error(f"Playback error for {rel}: {exc}", exc_info=True)
            except Exception as e:
                logger.error(f"Announcement error: {e}", exc_info=True)
            finally:
                self._playing = False

    def _build_sequence(self, number: str) -> List[str]:
        """Build the ordered list of MP3 relative paths to play: Chime -> Category -> Number."""
        if not self._data_dir:
            return []
        lang = self._language
        slug = _slug(self._category_display_name)
        seq = []

        # 1. Custom chime first (if exists)
        chime_path = os.path.join(self._data_dir, "announcement_chime.mp3")
        if os.path.isfile(chime_path):
            seq.append("announcement_chime.mp3")
        else:
            logger.debug(f"Custom chime sound not found at {chime_path}")

        # 2. Then category if enabled
        if self._category_audio_enabled:
            cat_path = os.path.join(self._data_dir, lang, "category", f"{slug}.mp3")
            if os.path.isfile(cat_path):
                seq.append(f"{lang}/category/{slug}.mp3")
            else:
                logger.debug(f"No category audio for '{slug}' in {lang}")

        # 3. Number last
        try:
            num_val = int(number)
        except ValueError:
            num_val = 0
        except Exception as e:
            logger.error(f"Error parsing number {number}: {e}", exc_info=True)
            return []
        seq.extend(self._digit_atoms(lang, num_val))

        return seq

    @staticmethod
    def _digit_atoms(lang: str, n: int) -> List[str]:
        atoms = []
        clamped = max(0, min(999, n))  # Ensure we're within our pre-generated range
        atoms.append(f"{lang}/numbers/{clamped}.mp3")
        return atoms
