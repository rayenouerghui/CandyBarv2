"""
NetworkHelper — exposes LAN IP, public tracking URL, and admin URL to QML.

publicUrl  → http://<LAN-IP>:8080/          (read-only customer tracking page)
adminUrl   → http://<LAN-IP>:8080/admin     (PIN-protected staff page)
"""

import os
import socket

from PySide6.QtCore import QObject, Property, Signal

PUBLIC_PORT = 8080


def _get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


class NetworkHelper(QObject):
    publicUrlChanged = Signal()
    adminUrlChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        ip = _get_local_ip()
        self._public_url = f"http://{ip}:{PUBLIC_PORT}/"
        self._admin_url = f"http://{ip}:{PUBLIC_PORT}/admin"
        print(f"[NetworkHelper] Public URL : {self._public_url}")
        print(f"[NetworkHelper] Admin URL  : {self._admin_url}")

    @Property(str, notify=publicUrlChanged)
    def publicUrl(self) -> str:
        return self._public_url

    @Property(str, notify=adminUrlChanged)
    def adminUrl(self) -> str:
        return self._admin_url
