
"""
Common utilities for CandyBarv2
"""
import os
from PySide6.QtCore import QStandardPaths


def get_app_data_dir() -> str:
    """
    Returns the path to the application data directory, creating it if needed.
    Standard location (cross-platform).
    """
    data_dir = QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.AppLocalDataLocation
    )
    os.makedirs(data_dir, exist_ok=True)
    return data_dir

