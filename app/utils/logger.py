
"""
Professional logging system for CandyBar
"""
import os
import sys
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
from datetime import datetime


def setup_logger(name: str = "candybar", log_dir: str = None) -> logging.Logger:
    """
    Set up a professional logger with file and console handlers.
    
    Args:
        name: Logger name
        log_dir: Directory for log files (defaults to ~/.local/share/candybar/logs)
    
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    logger.propagate = False  # Don't propagate to root logger
    
    # Clear any existing handlers
    if logger.handlers:
        logger.handlers.clear()
    
    # Determine log directory
    if log_dir is None:
        # Use standard location for application data
        if sys.platform.startswith("win"):
            base_dir = Path(os.environ.get("LOCALAPPDATA", Path.home()))
        else:
            base_dir = Path.home() / ".local" / "share"
        log_dir = base_dir / "candybar" / "logs"
    
    log_dir = Path(log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # Log file with date
    log_file = log_dir / f"candybar_{datetime.now().strftime('%Y%m%d')}.log"
    
    # Formatter
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    
    # File handler - rotates at 5MB, keeps 5 backups
    file_handler = RotatingFileHandler(
        log_file,
        maxBytes=5 * 1024 * 1024,  # 5 MB
        backupCount=5,
        encoding="utf-8"
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    logger.info(f"Logger initialized. Log file: {log_file}")
    return logger


# Global logger instance
_logger_instance = None


def get_logger() -> logging.Logger:
    """Get the global logger instance (creates it if needed)."""
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = setup_logger()
    return _logger_instance
