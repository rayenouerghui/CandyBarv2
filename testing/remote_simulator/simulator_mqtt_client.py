"""
MQTT Client for Remote Controller Simulator
Uses paho-mqtt to communicate with EMQX broker over TCP :1883
"""
import uuid
import threading
import logging

import paho.mqtt.client as mqtt

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SimulatorMQTTClient:
    """MQTT client wrapper for the remote simulator."""
    
    def __init__(self, host="localhost", port=1883, username=None, password=None):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        
        # Generate unique client ID (different from production)
        self.client_id = f"candybar-remote-simulator-{uuid.uuid4().hex[:8]}"
        
        self._connected = False
        self._client = None
        self._message_log = []
        self._log_callback = None
        
        logger.info(f"Simulator MQTT client initialized: {self.client_id}")
    
    def set_log_callback(self, callback):
        """Set callback for message logging."""
        self._log_callback = callback
    
    def _log(self, message):
        """Internal logging with optional callback."""
        logger.info(message)
        self._message_log.append(message)
        if self._log_callback:
            self._log_callback(message)
    
    def connect(self):
        """Connect to MQTT broker."""
        if self._connected:
            self._log("Already connected")
            return True
        
        try:
            self._client = mqtt.Client(client_id=self.client_id)
            
            if self.username and self.password:
                self._client.username_pw_set(self.username, self.password)
            
            self._client.on_connect = self._on_connect
            self._client.on_disconnect = self._on_disconnect
            self._client.on_publish = self._on_publish
            
            self._client.connect(self.host, self.port, keepalive=60)
            
            # Start network loop in separate thread
            self._client.loop_start()
            
            self._log(f"Connecting to {self.host}:{self.port}...")
            return True
            
        except Exception as e:
            self._log(f"Connection failed: {e}")
            logger.error(f"MQTT connection error: {e}", exc_info=True)
            return False
    
    def disconnect(self):
        """Disconnect from MQTT broker."""
        if self._client:
            self._client.loop_stop()
            self._client.disconnect()
            self._connected = False
            self._log("Disconnected from broker")
    
    def _on_connect(self, client, userdata, flags, rc):
        """Callback for connection."""
        if rc == 0:
            self._connected = True
            self._log(f"Connected to broker as {self.client_id}")
        else:
            self._connected = False
            self._log(f"Connection failed with code {rc}")
    
    def _on_disconnect(self, client, userdata, rc):
        """Callback for disconnection."""
        self._connected = False
        if rc == 0:
            self._log("Disconnected cleanly")
        else:
            self._log(f"Unexpected disconnect (rc={rc})")
    
    def _on_publish(self, client, userdata, mid):
        """Callback for successful publish."""
        self._log(f"Message published (mid={mid})")
    
    def publish_number(self, category, number):
        """
        Publish a queue number to the CandyBar display.
        
        Args:
            category: Category letter (A, B, C, D)
            number: Queue number as string (e.g., "042", "123")
        
        Returns:
            bool: True if publish was attempted, False if not connected
        """
        if not self._connected:
            self._log("Not connected - cannot publish")
            return False
        
        # Validate number format (1-3 digits, max 999)
        # Handle |nosound flag by stripping it for validation
        number_for_validation = number.split('|')[0] if '|' in number else number
        try:
            num_val = int(number_for_validation)
            if num_val < 0 or num_val > 999:
                self._log(f"Invalid number {number}: must be 0-999")
                return False
        except ValueError:
            self._log(f"Invalid number {number}: not a valid integer")
            return False
        
        # Construct topic: display/<category>/currentNumber
        topic = f"display/{category}/currentNumber"
        payload = number
        
        try:
            result = self._client.publish(topic, payload)
            self._log(f"PUBLISH: {topic} → {payload}")
            return True
        except Exception as e:
            self._log(f"Publish failed: {e}")
            logger.error(f"MQTT publish error: {e}", exc_info=True)
            return False
    
    def is_connected(self):
        """Check if connected to broker."""
        return self._connected
    
    def get_message_log(self):
        """Get the message log."""
        return self._message_log.copy()
    
    def clear_log(self):
        """Clear the message log."""
        self._message_log.clear()
