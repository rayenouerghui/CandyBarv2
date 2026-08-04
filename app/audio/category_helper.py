
"""
CategoryAudioHelper — generate category name MP3s via Edge-TTS.
Always overwrites existing files for safety.
"""
import os
import re
import threading
import asyncio
from pathlib import Path

from app.utils.logger import get_logger

logger = get_logger()

_MIN_VALID_BYTES = 1024


def _slug(name: str) -> str:
    return re.sub(r"[^\w\-]", "_", name.lower().strip())[:48]


def generate_category_audio(display_name: str, output_dir: str):
    """Generate (or regenerate) category MP3s in a daemon thread."""
    threading.Thread(
        target=_generate_sync,
        args=(display_name, output_dir),
        daemon=True,
    ).start()


def is_valid_mp3(path: str) -> bool:
    """Check if MP3 file exists and is valid size."""
    try:
        return os.path.isfile(path) and os.path.getsize(path) >= _MIN_VALID_BYTES
    except OSError as e:
        logger.warning(f"Error checking MP3 file {path}: {e}")
        return False


def _generate_sync(display_name: str, output_dir: str):
    name = display_name.strip()
    if not name:
        return
    try:
        import edge_tts
    except ImportError:
        logger.warning("edge-tts not installed — skipping category audio generation")
        return

    voices = {
        "en": "en-US-AriaNeural",
        "fr": "fr-FR-DeniseNeural",
        "ar": "ar-SA-HamedNeural",
    }
    slug = _slug(name)
    out = Path(output_dir)

    async def _gen(lang: str, voice: str):
        cat_dir = out / lang / "category"
        cat_dir.mkdir(parents=True, exist_ok=True)
        path = cat_dir / f"{slug}.mp3"
        tmp = cat_dir / f"{slug}.mp3.tmp"

        try:
            communicate = edge_tts.Communicate(name, voice)
            await communicate.save(str(tmp))
            size = tmp.stat().st_size if tmp.exists() else 0
            if size < _MIN_VALID_BYTES:
                logger.warning(f"Generated file too small ({size}B), discarding: {tmp}")
                tmp.unlink(missing_ok=True)
                return
            tmp.replace(path)
            logger.info(f"Generated category audio: {path} ({size} bytes)")
        except Exception as e:
            logger.error(f"Error generating {lang} audio for '{name}': {e}", exc_info=True)
            tmp.unlink(missing_ok=True)

    async def _run_all():
        for lang, voice in voices.items():
            try:
                await _gen(lang, voice)
            except Exception as exc:
                logger.error(f"{lang} generation error for '{name}': {exc}", exc_info=True)

    import locale
    old_loc = None
    try:
        old_loc = locale.setlocale(locale.LC_TIME)
        locale.setlocale(locale.LC_TIME, 'C')
    except Exception as e:
        logger.debug(f"Could not adjust LC_TIME locale: {e}")

    try:
        asyncio.run(_run_all())
    except Exception as exc:
        logger.error(f"Fatal category audio generation error: {exc}", exc_info=True)
    finally:
        if old_loc is not None:
            try:
                locale.setlocale(locale.LC_TIME, old_loc)
            except Exception:
                pass
