"""
AudioEngine.py — TTS audio playback engine for CandyBarV2.
Hybrid pre-generation + runtime playback. No live TTS at runtime.
Uses pygame.mixer.music for sequential atom playback (MP3 supported).

SYNCHRONIZATION MODEL
----------------------
Exactly ONE background worker thread ever touches pygame.mixer. All
"play this number" requests go through a queue.Queue that the worker
consumes one at a time, so playback is always serialized — there is
never a race between two announcements.

Callers (Qt slots on the UI thread) never block on playback:
  - announceNumber() / stop() only flip a threading.Event and push to
    the queue. Both are O(1) and return immediately.
  - The ONLY authoritative "audio has finished" signal is
    announcementFinished, emitted from inside the worker thread's
    finally block — i.e. it fires exactly once per request, exactly
    when playback (or an interruption) has actually completed. Any UI
    logic that needs to know "is it safe to move to the next number"
    should hook into that signal instead of guessing based on timers.
"""
import os
import queue
import re
import threading
import time
from typing import List, Optional

from PySide6.QtCore import QObject, Signal, Slot, Property

try:
    import pygame
    import pygame.mixer
except ImportError:
    pygame = None

from app.utils.logger import get_logger

logger = get_logger()


def _slug(name: str) -> str:
    """Normalise a display name to a safe filename slug."""
    return re.sub(r"[^\w\-]", "_", name.lower().strip())[:48]


class AudioEngine(QObject):
    VOLUME_STEPS = [0.0, 0.35, 0.55, 0.75, 1.0]
    SEQUENCE_GAP_SECONDS = 0.0
    ANNOUNCE_DEBOUNCE_SECONDS = 0.05

    # Qt signals so QML can bind reactively instead of polling.
    playingChanged = Signal(bool)
    # Emits the number that finished playing, or "" if it was interrupted
    # (e.g. a newer announcement pre-empted it). This is the single
    # source of truth for "audio has ended".
    announcementFinished = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._initialized = False
        self._muted = False
        self._volume_step = 3  # index into VOLUME_STEPS (default ~0.75)
        self._language = "en"
        self._data_dir = ""
        self._playing = False
        self._category_display_name = "Counter A"
        self._tts_enabled = True
        self._category_audio_enabled = True
        self._on_state_change = None  # optional callback: dict -> None

        # --- synchronization primitives ---
        # state_lock protects ONLY quick bookkeeping (the debounce timer
        # handle). It is never held across a blocking pygame call, so it
        # can never freeze a caller.
        self._state_lock = threading.Lock()
        # Flips instantly to ask the currently-playing sequence to stop.
        # Reading/writing an Event is safe across threads with no lock.
        self._stop_event = threading.Event()
        # Only ever holds at most the single latest pending number —
        # older stale requests are dropped in _debounced_announce so the
        # worker never plays two things back-to-back for the same click.
        self._queue: "queue.Queue[str]" = queue.Queue()
        self._debounce_timer = None

        self._init_mixer()

        # Single long-lived worker thread. Replaces the old "spawn a new
        # thread per announcement" approach — this IS the synchronizer.
        self._worker = threading.Thread(target=self._worker_loop, daemon=True)
        self._worker.start()

    def set_broadcast_callback(self, callback):
        """Wired up by main.py once the WS server exists. callback(dict) -> None.
        Never allowed to affect audio playback even if it raises."""
        self._on_state_change = callback

    def _notify_playing(self, playing: bool):
        """Best-effort notification — must NEVER let a broadcast failure
        break or interrupt audio playback."""
        cb = self._on_state_change
        if cb is None:
            return
        try:
            cb({"type": "state_patch", "key": "audioPlaying", "value": playing})
        except Exception as e:
            logger.debug(f"[audio] broadcast notify failed (non-fatal): {e}")

    def _set_playing(self, playing: bool):
        self._playing = playing
        self.playingChanged.emit(playing)
        self._notify_playing(playing)

    def _init_mixer(self):
        if pygame is None:
            logger.warning("pygame not installed — audio disabled")
            return
        try:
            pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
            self._initialized = True
            logger.info("Audio mixer initialized OK")
        except Exception as e:
            self._initialized = False
            logger.error(f"Failed to initialize audio: {e}", exc_info=True)

    def _ensure_mixer_ready(self) -> bool:
        """Retry init once if a previous attempt failed (e.g. audio device
        wasn't ready yet at boot). Cheap no-op if already initialized."""
        if self._initialized:
            return True
        logger.info("Mixer not initialized — retrying init")
        self._init_mixer()
        return self._initialized

    # --- Qt properties -----------------------------------------------

    @Property(bool)
    def muted(self):
        return self._muted

    @muted.setter
    def muted(self, value):
        self._muted = bool(value)
        if not self._initialized:
            return
        try:
            if self._muted:
                pygame.mixer.music.set_volume(0.0)
            else:
                pygame.mixer.music.set_volume(self.VOLUME_STEPS[self._volume_step])
        except Exception as e:
            logger.warning(f"Error applying mute state: {e}")

    @Property(int)
    def volumeStep(self):
        return self._volume_step

    @volumeStep.setter
    def volumeStep(self, value):
        self._volume_step = max(0, min(len(self.VOLUME_STEPS) - 1, int(value)))
        if not self._initialized or self._muted:
            return
        try:
            if pygame.mixer.music.get_busy():
                pygame.mixer.music.set_volume(self.VOLUME_STEPS[self._volume_step])
        except Exception as e:
            logger.warning(f"Error applying volume step: {e}")

    @Property(float)
    def volume(self):
        return self.VOLUME_STEPS[self._volume_step]

    @Property(bool, notify=playingChanged)
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
            # Run generation in the background — this can involve real
            # work (TTS synthesis), and must never block the calling
            # (UI) thread.
            threading.Thread(
                target=self._ensure_category_audio,
                args=(clean,),
                daemon=True,
            ).start()

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
            from app.audio.category_helper import generate_category_audio
            generate_category_audio(name, self._data_dir)
        except Exception as e:
            logger.error(f"Category audio generation failed: {e}", exc_info=True)

    # --- announce / stop (non-blocking, called from UI thread) --------

    @Slot(str)
    def announceNumber(self, number: str):
        """Announce: number + [category name] (debounced).
        Non-blocking: only signals the worker and returns immediately,
        even if a previous announcement is still mid-playback."""
        if not self._ensure_mixer_ready() or self._muted or not self._tts_enabled:
            logger.debug(
                f"Audio blocked — init={self._initialized} muted={self._muted} tts={self._tts_enabled}"
            )
            return

        # Ask any in-flight playback to stop ASAP. This does NOT wait —
        # it just flips a flag the worker thread checks between/within
        # playback steps.
        self._stop_event.set()

        with self._state_lock:
            if self._debounce_timer is not None:
                self._debounce_timer.cancel()
            self._debounce_timer = threading.Timer(
                self.ANNOUNCE_DEBOUNCE_SECONDS,
                self._debounced_announce,
                args=(number,),
            )
            self._debounce_timer.start()

    def _debounced_announce(self, number: str):
        with self._state_lock:
            self._debounce_timer = None

        # Only the latest request matters — drop anything stale so the
        # worker never plays a backlog of superseded numbers.
        with self._queue.mutex:
            self._queue.queue.clear()
        self._queue.put(number)

    @Slot()
    def stop(self):
        """Non-blocking stop: signals the worker and clears pending work,
        but does not wait for the worker to finish tearing down."""
        self._stop_event.set()
        with self._state_lock:
            if self._debounce_timer is not None:
                self._debounce_timer.cancel()
                self._debounce_timer = None
        with self._queue.mutex:
            self._queue.queue.clear()
        if self._initialized:
            try:
                pygame.mixer.music.stop()
            except Exception as e:
                logger.warning(f"Error stopping audio playback: {e}")

    # --- worker thread (the only thread that touches pygame.mixer) ----

    def _worker_loop(self):
        """Runs for the lifetime of the app. Pulls one announcement at a
        time and plays it fully, or until interrupted. Because there is
        exactly one worker, playback is always serialized."""
        while True:
            number = self._queue.get()

            # Clear the stop flag right before starting this request, so
            # a stop_event set while we were idle waiting on the queue
            # doesn't immediately cancel the request we're about to play.
            self._stop_event.clear()
            self._play_announcement(number)

    def _play_announcement(self, number: str):
        self._set_playing(True)
        interrupted = False
        try:
            files = self._build_sequence(number)
            if not files:
                logger.warning(f"Empty sequence for number '{number}'")
                return
            vol = self.VOLUME_STEPS[self._volume_step]
            gap = self.SEQUENCE_GAP_SECONDS
            for rel in files:
                if self._stop_event.is_set():
                    interrupted = True
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
                        if self._stop_event.is_set():
                            pygame.mixer.music.stop()
                            interrupted = True
                            break
                        if is_chime and (time.time() - start_time >= 3.0):
                            pygame.mixer.music.stop()
                            break
                        time.sleep(0.01)

                    if interrupted:
                        break
                    time.sleep(gap)
                except Exception as exc:
                    logger.error(f"Playback error for {rel}: {exc}", exc_info=True)
        except Exception as e:
            logger.error(f"Announcement error: {e}", exc_info=True)
        finally:
            self._set_playing(False)
            # The single authoritative "audio has ended" event. Fires
            # exactly once per request, whether it finished naturally or
            # was cut short by a newer announcement / stop().
            self.announcementFinished.emit("" if interrupted else number)

    def _build_sequence(self, number: str) -> List[str]:
        """Build the ordered list of MP3 relative paths to play: Chime -> Category -> Number word -> Number."""
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

        # 3. Then the spoken word "number" (English/French/Arabic)
        word_path = os.path.join(self._data_dir, lang, "number.mp3")
        if os.path.isfile(word_path):
            seq.append(f"{lang}/number.mp3")
        else:
            logger.debug(f"No number word audio for {lang}")

        # 4. Number last
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