import pathlib
import shutil
import tempfile
from unittest.mock import patch

from main import _copy_static_assets_to_data_dir


def test_copy_static_assets_to_data_dir_copies_language_number_audio(tmp_path):
    project_root = pathlib.Path(__file__).resolve().parents[1]
    resources_audio = project_root / "resources" / "audio"
    data_dir = tmp_path / "data"

    # Create a minimal fake audio tree similar to the expected structure.
    (resources_audio / "en" / "numbers").mkdir(parents=True, exist_ok=True)
    (resources_audio / "en" / "category").mkdir(parents=True, exist_ok=True)
    (resources_audio / "en" / "number.mp3").write_bytes(b"audio")
    (resources_audio / "en" / "numbers" / "1.mp3").write_bytes(b"one")
    (resources_audio / "en" / "category" / "counter_a.mp3").write_bytes(b"cat")

    try:
        with patch("main.QFile") as mock_qfile:
            mock_qfile.return_value.open.return_value = False
            _copy_static_assets_to_data_dir(str(data_dir))

        copied_number = data_dir / "audio" / "en" / "numbers" / "1.mp3"
        copied_word = data_dir / "audio" / "en" / "number.mp3"
        copied_category = data_dir / "audio" / "en" / "category" / "counter_a.mp3"

        assert copied_number.exists()
        assert copied_word.exists()
        assert copied_category.exists()
    finally:
        shutil.rmtree(resources_audio / "en", ignore_errors=True)
