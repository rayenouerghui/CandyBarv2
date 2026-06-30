"""
MQTTClient — bridges paho-mqtt callbacks into PySide6 Qt signals.

Runs paho's network loop in a background daemon thread.
Qt's queued connection mechanism marshals all signals safely to the main thread.

Broker address is read from environment variables so it can be changed
via a systemd unit file without touching code:

  CANDYBAR_MQTT_HOST  — hostname or IP of the EMQX broker (default: localhost)
  CANDYBAR_MQTT_PORT  — TCP port                           (default: 1883)
  CANDYBAR_MQTT_USER  — username, if EMQX auth is enabled  (default: empty)
  CANDYBAR_MQTT_PASS  — password, if EMQX auth is enabled  (default: empty)

For the default on-device deployment EMQX runs on the same machine, so the
defaults work without setting anything. Set the env vars in the systemd unit
if the broker is moved to a separate device or auth is later enabled.

Signals:
  displayCommandReceived(key, value)  — routed to DisplayState.applyMqttCommand()
  connectedChanged()                  — bool flip
  connectionStatusChanged(status)     — human-readable text
  messageReceived(topic, payload)     — raw, used by stats tracking
"""

import os
import threading

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Slot, Property

_BROKER = os.environ.get("CANDYBAR_MQTT_HOST", "localhost")
_PORT   = int(os.environ.get("CANDYBAR_MQTT_PORT", "1883"))
_USER   = os.environ.get("CANDYBAR_MQTT_USER", "")
_PASS   = os.environ.get("CANDYBAR_MQTT_PASS", "")


class MQTTClient(QObject):
    connectionStatusChanged = Signal(str)
    connectedChanged = Signal()
    displayCommandReceived = Signal(str, str)
    messageReceived = Signal(str, str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._broker = _BROKER
        self._port = _PORT
        self._connected = False
        self._status = "Connecting…"

        self._client = mqtt.Client(client_id="candybar-display")
        if _USER:
            self._client.username_pw_set(_USER, _PASS)
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
