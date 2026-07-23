#!/usr/bin/env python3
"""Generate number audio atoms for 0..999 and refresh the runtime audio directory."""
import asyncio
import shutil
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parents[1]
RESOURCES_AUDIO = ROOT / "resources" / "audio"
RUNTIME_AUDIO = Path.home() / ".local" / "share" / "CandyBarV2" / "CandyBarV2" / "audio"
LANGS = ["en", "fr", "ar"]
MIN_SIZE = 2048


async def _pick_voice(lang: str) -> str:
    voices = await edge_tts.list_voices()
    for voice in voices:
        short_name = voice.get("ShortName", "")
        locale = voice.get("Locale", "")
        if lang == "en" and locale.lower().startswith("en"):
            return short_name
        if lang == "fr" and locale.lower().startswith("fr"):
            return short_name
        if lang == "ar" and locale.lower().startswith("ar"):
            return short_name
    raise RuntimeError(f"No voice found for language {lang}")


async def _generate_number(lang: str, voice: str, number: int, out_file: Path) -> None:
    tmp_path = out_file.with_suffix(".mp3.tmp")
    communicate = edge_tts.Communicate(str(number), voice=voice)
    await communicate.save(str(tmp_path))
    if tmp_path.exists() and tmp_path.stat().st_size > MIN_SIZE:
        shutil.move(str(tmp_path), str(out_file))
    else:
        tmp_path.unlink(missing_ok=True)
        raise RuntimeError(f"Generated file too small for {lang}/{number}")


def _copy_to_runtime(lang: str) -> None:
    src_dir = RESOURCES_AUDIO / lang / "numbers"
    dst_dir = RUNTIME_AUDIO / lang / "numbers"
    if not src_dir.exists():
        return
    dst_dir.mkdir(parents=True, exist_ok=True)
    for mp3_file in src_dir.glob("*.mp3"):
        dst_file = dst_dir / mp3_file.name
        if not dst_file.exists() or dst_file.stat().st_size <= MIN_SIZE:
            shutil.copy2(mp3_file, dst_file)


def main() -> None:
    RESOURCES_AUDIO.mkdir(parents=True, exist_ok=True)
    RUNTIME_AUDIO.mkdir(parents=True, exist_ok=True)

    for lang in LANGS:
        numbers_dir = RESOURCES_AUDIO / lang / "numbers"
        numbers_dir.mkdir(parents=True, exist_ok=True)
        voice = asyncio.run(_pick_voice(lang))
        print(f"Generating {lang} numbers with {voice}")

        for number in range(1000):
            out_file = numbers_dir / f"{number}.mp3"
            if out_file.exists() and out_file.stat().st_size > MIN_SIZE:
                continue
            try:
                asyncio.run(_generate_number(lang, voice, number, out_file))
                print(f"generated {lang}/{number}.mp3")
            except Exception as exc:
                print(f"failed {lang}/{number}: {exc}")

        _copy_to_runtime(lang)

    print("Audio generation complete")


if __name__ == "__main__":
    main()
