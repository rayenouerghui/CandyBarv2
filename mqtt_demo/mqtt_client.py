"""
MQTTClient — bridges paho-mqtt callbacks into PySide6 Qt signals.

Runs paho's network loop in a background daemon thread.
Qt's queued connection mechanism marshals all signals safely to the main thread.

Signals:
  displayCommandReceived(key, value)  — routed to DisplayState.applyMqttCommand()
  connectedChanged()                  — bool flip
  connectionStatusChanged(status)     — human-readable text
  messageReceived(topic, payload)     — raw, used by stats tracking
"""

import threading

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Slot, Property


class MQTTClient(QObject):
    connectionStatusChanged = Signal(str)
    connectedChanged = Signal()
    displayCommandReceived = Signal(str, str)
    messageReceived = Signal(str, str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._broker = "localhost"
        self._port = 1883
        self._connected = False
        self._status = "Connecting…"

        self._client = mqtt.Client(client_id="candybar-display")
        self._client.on_connect = self._on_connect
        self._client.on_disconnect = self._on_disconnect
        self._client.on_message = self._on_message

    # ── QML-visible properties ────────────────────────────────────────────

    @Property(bool, notify=connectedChanged)
    def connected(self):
        return self._connected

    @Property(str, notify=connectionStatusChanged)
    def status(self):
        return self._status

    @Property(str, constant=True)
    def broker(self):
        return f"{self._broker}:{self._port}"

    # ── Slots callable from QML ───────────────────────────────────────────

    @Slot()
    def connect_broker(self):
        if self._connected:
            return
        try:
            self._client.connect(self._broker, self._port, keepalive=60)
            t = threading.Thread(target=self._client.loop_forever, daemon=True)
            t.start()
        except Exception as exc:
            self._set_status(f"Error: {exc}")

    @Slot()
    def disconnect_broker(self):
        self._client.disconnect()

    @Slot(str)
    def publish(self, topic: str, payload: str):
        """Publish to an arbitrary topic — used by admin_web server."""
        if self._connected:
            self._client.publish(topic, payload)

    # ── paho callbacks (run in paho's thread) ─────────────────────────────

    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self._connected = True
            self._set_status("Connected")
            self.connectedChanged.emit()
            client.subscribe("display/#")
        else:
            self._set_status(f"Refused (rc={rc})")

    def _on_disconnect(self, client, userdata, rc):
        self._connected = False
        self._set_status("Reconnecting…")
        self.connectedChanged.emit()

    def _on_message(self, client, userdata, msg):
        topic = msg.topic
        payload = msg.payload.decode("utf-8", errors="replace")
        self.messageReceived.emit(topic, payload)
        if topic.startswith("display/"):
            key = topic[len("display/"):]
            self.displayCommandReceived.emit(key, payload)

    def _set_status(self, text: str):
        self._status = text
        self.connectionStatusChanged.emit(text)
