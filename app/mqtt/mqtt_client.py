
"""
MQTTClient — bridges paho-mqtt callbacks into PySide6 Qt signals.
"""
import os
import queue
import threading

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer

from app.utils.logger import get_logger

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
        # _connected now reflects real broker state.
        self._connected = False
        self._status = "Disconnected"
        self._category = "A"
        self._cmd_queue: queue.Queue = queue.Queue()
        self._drain_timer = QTimer(self)
        self._drain_timer.setInterval(200)
        self._drain_timer.timeout.connect(self._drain_queue)
        self._drain_timer.start()
        self._reconnect_delay = 1.0
        self._reconnect_max_delay = 30.0
        self._reconnect_timer = QTimer(self)
        self._reconnect_timer.setSingleShot(True)
        self._reconnect_timer.timeout.connect(self.connect_broker)
        self._client = mqtt.Client(client_id="candybar-display")
        if _USER:
            self._client.username_pw_set(_USER, _PASS)
        # Once loop_forever() is running, let paho retry/backoff on its own —
        # avoids spawning duplicate reconnect threads.
        self._client.reconnect_delay_set(min_delay=1, max_delay=30)
        self._client.on_connect = self._on_connect
        self._client.on_disconnect = self._on_disconnect
        self._client.on_message = self._on_message
        self.connectedChanged.emit()
        self.connectionStatusChanged.emit(self._status)
        logger.info(f"MQTT client initialized: {self._broker}:{self._port}")

    def _drain_queue(self):
        # NOTE: intentionally unconditional. This queue carries two kinds of
        # items: (1) local admin commands from direct_command(), which must
        # reach QML regardless of MQTT broker status — that's the whole
        # point of direct_command existing; and (2) real MQTT messages from
        # _on_message(), which paho only calls while genuinely connected and
        # subscribed, so a stale/fake connection can never populate this
        # queue with MQTT data. Gating the drain on self._connected blocks
        # case (1) for no benefit to case (2) — do not re-add this guard.
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
            self._connected = False
            self._set_status("Disconnected")
            self.connectedChanged.emit()
            if "Connection refused" in str(exc):
                logger.debug(f"MQTT broker not available: {exc}")
            else:
                logger.error(f"Failed to connect to MQTT broker: {exc}", exc_info=True)
            self._schedule_reconnect()

    @Slot()
    def disconnect_broker(self):
        self._reconnect_timer.stop()
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
            self._reconnect_delay = 1.0
            self._set_status("Connected")
            self.connectedChanged.emit()
            client.subscribe(f"display/{self._category}/#")
            logger.info("MQTT connected and subscribed")
        else:
            self._connected = False
            self._set_status(f"Refused (rc={rc})")
            self.connectedChanged.emit()
            logger.error(f"MQTT connection refused, rc={rc}")

    def _on_disconnect(self, client, userdata, rc):
        self._connected = False
        if rc == 0:
            self._set_status("Disconnected")
            logger.debug("MQTT disconnected cleanly")
        else:
            self._set_status("Disconnected (unexpected)")
            logger.warning(f"MQTT disconnected unexpectedly, rc={rc}")
        self.connectedChanged.emit()

    def _schedule_reconnect(self):
        if self._reconnect_timer.isActive():
            return
        logger.info(f"Scheduling MQTT reconnect in {self._reconnect_delay:.1f}s")
        self._reconnect_timer.start(int(self._reconnect_delay * 1000))
        self._reconnect_delay = min(self._reconnect_delay * 2, self._reconnect_max_delay)

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
