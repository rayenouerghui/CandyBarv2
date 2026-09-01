
"""
NetworkHelper — exposes LAN IP, public tracking URL, admin URL, and site URL.
"""
import socket

from PySide6.QtCore import QObject, Property, Signal

from app.utils.logger import get_logger

logger = get_logger()

CANDYBAR_SITE_URL = "https://candybarv2.app"
PUBLIC_PORT = 8080


def _get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        logger.warning(f"Could not determine local IP: {e}")
        return "127.0.0.1"


class NetworkHelper(QObject):
    publicUrlChanged = Signal()
    adminUrlChanged = Signal()
    siteUrlChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        ip = _get_local_ip()
        self._public_url = f"http://{ip}:{PUBLIC_PORT}/"
        self._admin_url = f"http://{ip}:{PUBLIC_PORT}/admin"
        self._site_url = CANDYBAR_SITE_URL
        banner = (
            "\n┌─────────────────────────────────────────────────┐\n"
            "│              CandyBarV2  —  ready               │\n"
            "├─────────────────────────────────────────────────┤\n"
            f"│  Admin panel  :  {self._admin_url:<31}│\n"
            f"│  Public page  :  {self._public_url:<31}│\n"
            f"│  Site URL     :  {self._site_url:<31}│\n"
            "└─────────────────────────────────────────────────┘\n"
        )
        logger.info(banner)
        logger.info(f"Network URLs initialized: admin={self._admin_url}, public={self._public_url}")

    @Property(str, notify=publicUrlChanged)
    def publicUrl(self) -> str:
        return self._public_url

    @Property(str, notify=adminUrlChanged)
    def adminUrl(self) -> str:
        return self._admin_url

    @Property(str, notify=siteUrlChanged)
    def siteUrl(self) -> str:
        return self._site_url
