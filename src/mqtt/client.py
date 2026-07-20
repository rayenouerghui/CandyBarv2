
"""
MQTTClient — bridges paho-mqtt callbacks into PySide6 Qt signals.
"""
import os
import queue
import threading

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer

from src.logging import get_logger

logger = get_logger()

_BROKER = os.environ.get("CANDYBAR_MQTT_HOST", "localhost")
_PORT = int(os.environ.get("CANDYBAR_MQTT_PORT", "1883"))
_USER = os.environ.get("CANDYBAR_MQTT_USER", "")
_PASS = os.environ.get("CANDYBAR_MQTT_PASS", "")


class MQTTClient(QObject):
    connectionStatusChanged = Signal(str)
    connectedChanged = Signal()
    displayCommandReceived = Signal(str, str)
    messageReceived = Signal(str, str)
    categoryChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._broker = _BROKER
        self._port = _PORT
        self._connected = False
        self._status = "Connecting…"
        self._category = "A"
        self._cmd_queue: queue.Queue = queue.Queue()
        self._drain_timer = QTimer(self)
        self._drain_timer.setInterval(50)
        self._drain_timer.timeout.connect(self._drain_queue)
        self._drain_timer.start()
        self._client = mqtt.Client(client_id="candybar-display")
        if _USER:
            self._client.username_pw_set(_USER, _PASS)
        self._client.on_connect = self._on_connect
        self._client.on_disconnect = self._on_disconnect
        self._client.on_message = self._on_message
        logger.info(f"MQTT client initialized: {self._broker}:{self._port}")

    def _drain_queue(self):
        try:
            while True:
                key, value = self._cmd_queue.get_nowait()
                self.displayCommandReceived.emit(key, value)
        except queue.Empty:
            pass

    def direct_command(self, key: str, value: str):
        self._cmd_queue.put((key, value))

    @Property(bool, notify=connectedChanged)
    def connected(self):
        return self._connected

    @Property(str, notify=connectionStatusChanged)
    def status(self):
        return self._status

    @Property(str, constant=True)
    def broker(self):
        return f"{self._broker}:{self._port}"

    @Property(str, notify=categoryChanged)
    def category(self):
        return self._category

    @category.setter
    def category(self, value):
        if self._category != value:
            self._category = value
            self.categoryChanged.emit()
            if self._connected:
                try:
                    self._client.unsubscribe("display/#")
                    self._client.subscribe(f"display/{self._category}/#")
                    logger.info(f"Subscribed to category: {self._category}")
                except Exception as e:
                    logger.error(f"Error changing category subscription: {e}", exc_info=True)

    @Slot()
    def connect_broker(self):
        if self._connected:
            return
        try:
            self._client.connect(self._broker, self._port, keepalive=60)
            t = threading.Thread(target=self._client.loop_forever, daemon=True)
            t.start()
            logger.info("MQTT connection started")
        except Exception as exc:
            # Show friendly message when broker is not configured/available
            if "Connection refused" in str(exc):
                self._set_status("Not configured")
                logger.debug("MQTT broker not available (not configured)")
            else:
                self._set_status(f"Error: {exc}")
                logger.error(f"Failed to connect to MQTT broker: {exc}", exc_info=True)

    @Slot()
    def disconnect_broker(self):
        try:
            self._client.disconnect()
            logger.info("MQTT disconnected")
        except Exception as e:
            logger.warning(f"Error disconnecting MQTT: {e}")

    @Slot(str)
    def publish(self, topic: str, payload: str):
        if self._connected:
            try:
                self._client.publish(topic, payload)
                logger.debug(f"Published to {topic}: {payload}")
            except Exception as e:
                logger.error(f"Failed to publish to {topic}: {e}", exc_info=True)

    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self._connected = True
            self._set_status("Connected")
            self.connectedChanged.emit()
            client.subscribe(f"display/{self._category}/#")
            logger.info("MQTT connected and subscribed")
        else:
            self._set_status(f"Refused (rc={rc})")
            logger.error(f"MQTT connection refused, rc={rc}")

    def _on_disconnect(self, client, userdata, rc):
        self._connected = False
        # Show friendly message instead of error when broker is not available
        if rc == 0:
            self._set_status("Disconnected")
        else:
            self._set_status("Not configured")
        self.connectedChanged.emit()
        logger.debug("MQTT disconnected")

    def _on_message(self, client, userdata, msg):
        topic = msg.topic
        payload = msg.payload.decode("utf-8", errors="replace")
        self.messageReceived.emit(topic, payload)
        logger.debug(f"Received MQTT message: {topic} = {payload}")
        if topic.startswith("display/"):
            parts = topic.split("/")
            if len(parts) >= 3:
                self._cmd_queue.put((parts[2], payload))

    def _set_status(self, text: str):
        self._status = text
        self.connectionStatusChanged.emit(text)
