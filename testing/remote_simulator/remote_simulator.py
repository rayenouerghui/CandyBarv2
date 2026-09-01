#!/usr/bin/env python3
"""
Remote Controller Simulator - Main Entry Point

A development tool for simulating the physical Genical remote controller.
Uses paho-mqtt to communicate with EMQX broker over TCP :1883.

Usage:
    # From project root:
    python3 -m testing.remote_simulator.remote_simulator
    
    # From simulator directory:
    cd testing/remote_simulator && python3 remote_simulator.py
"""
import sys
import os
import time
import threading
from typing import Optional

# Add parent directory to path for imports when run directly
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

import tkinter as tk

try:
    from testing.remote_simulator.simulator_mqtt_client import SimulatorMQTTClient
    from testing.remote_simulator.button_mapping import ButtonMapping
    from testing.remote_simulator.ui.remote_ui import RemoteSimulatorUI
except ImportError:
    # Fallback for direct execution from simulator directory
    from simulator_mqtt_client import SimulatorMQTTClient
    from button_mapping import ButtonMapping
    from ui.remote_ui import RemoteSimulatorUI


class RemoteSimulator:
    """Main simulator application."""
    
    def __init__(self):
        self.root = tk.Tk()
        self.mqtt_client: Optional[SimulatorMQTTClient] = None
        self.ui = RemoteSimulatorUI(self.root)
        
        # Wire up UI callbacks
        self.ui.on_connect = self._on_connect
        self.ui.on_disconnect = self._on_disconnect
        self.ui.on_send_command = self._on_send_command
        self.ui.on_test_send_1 = self._on_test_send_1
        self.ui.on_test_send_10 = self._on_test_send_10
        self.ui.on_test_send_100 = self._on_test_send_100
        self.ui.on_test_rapid = self._on_test_rapid
        self.ui.on_test_disconnect_reconnect = self._on_test_disconnect_reconnect
        self.ui.on_test_invalid = self._on_test_invalid
        self.ui.on_test_duplicate = self._on_test_duplicate
        
        # Set MQTT log callback
        if self.mqtt_client:
            self.mqtt_client.set_log_callback(self.ui.add_log_message)
    
    def _on_connect(self):
        """Handle connect button from UI."""
        config = self.ui.get_connection_config()
        
        if not self.mqtt_client:
            self.mqtt_client = SimulatorMQTTClient(
                host=config["host"],
                port=config["port"],
                username=config["username"],
                password=config["password"]
            )
            self.mqtt_client.set_log_callback(self.ui.add_log_message)
        
        if self.mqtt_client.connect():
            # Wait a moment for connection to establish
            self.root.after(1000, self._check_connection_status)
        else:
            self.ui.set_connection_status(False)
    
    def _check_connection_status(self):
        """Check and update connection status."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            self.ui.set_connection_status(True)
        else:
            self.ui.set_connection_status(False)
    
    def _on_disconnect(self):
        """Handle disconnect button from UI."""
        if self.mqtt_client:
            self.mqtt_client.disconnect()
            self.ui.set_connection_status(False)
    
    def _on_send_command(self, category: str, number: str):
        """Handle number send from button mapping."""
        if self.mqtt_client:
            success = self.mqtt_client.publish_number(category, number)
            if not success:
                self.ui.add_log_message(f"Failed to send: {category}/{number}")
    
    def _on_test_send_1(self):
        """Test: Send 1 command."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            category = self.ui.selected_category
            self.mqtt_client.publish_number(category, "001")
            self.ui.add_log_message(f"TEST: Sent 1 command to {category}")
        else:
            self.ui.add_log_message("TEST ERROR: Not connected")
    
    def _on_test_send_10(self):
        """Test: Send 10 commands."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            category = self.ui.selected_category
            for i in range(10):
                num = str(i + 1).zfill(3)
                self.mqtt_client.publish_number(category, num)
                time.sleep(0.1)
            self.ui.add_log_message(f"TEST: Sent 10 commands (001-010) to {category}")
        else:
            self.ui.add_log_message("TEST ERROR: Not connected")
    
    def _on_test_send_100(self):
        """Test: Send 100 commands."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            category = self.ui.selected_category
            for i in range(100):
                num = str(i + 1).zfill(3)
                self.mqtt_client.publish_number(category, num)
                time.sleep(0.05)
            self.ui.add_log_message(f"TEST: Sent 100 commands (001-100) to {category}")
        else:
            self.ui.add_log_message("TEST ERROR: Not connected")
    
    def _on_test_rapid(self):
        """Test: Rapid button presses."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            category = self.ui.selected_category
            # Simulate rapid digit entry
            for digit in ["1", "2", "3", "4", "5"]:
                self.ui.button_mapping.handle_button(
                    getattr(self.ui.button_mapping.ButtonAction, f"DIGIT_{digit}")
                )
                time.sleep(0.05)
            # Force send
            self.ui.button_mapping.force_send()
            self.ui.add_log_message(f"TEST: Rapid button presses to {category}")
        else:
            self.ui.add_log_message("TEST ERROR: Not connected")
    
    def _on_test_disconnect_reconnect(self):
        """Test: Disconnect and reconnect."""
        if self.mqtt_client:
            self.ui.add_log_message("TEST: Disconnecting...")
            self.mqtt_client.disconnect()
            self.ui.set_connection_status(False)
            time.sleep(2)
            self.ui.add_log_message("TEST: Reconnecting...")
            config = self.ui.get_connection_config()
            if self.mqtt_client.connect():
                self.root.after(1000, self._check_connection_status)
            else:
                self.ui.set_connection_status(False)
    
    def _on_test_invalid(self):
        """Test: Invalid payload."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            category = self.ui.selected_category
            # Try to send invalid number (> 999)
            success = self.mqtt_client.publish_number(category, "1000")
            if not success:
                self.ui.add_log_message(f"TEST: Invalid payload rejected as expected")
            else:
                self.ui.add_log_message(f"TEST WARNING: Invalid payload was accepted")
        else:
            self.ui.add_log_message("TEST ERROR: Not connected")
    
    def _on_test_duplicate(self):
        """Test: Duplicate command."""
        if self.mqtt_client and self.mqtt_client.is_connected():
            category = self.ui.selected_category
            # Send same number twice
            self.mqtt_client.publish_number(category, "042")
            time.sleep(0.1)
            self.mqtt_client.publish_number(category, "042")
            self.ui.add_log_message(f"TEST: Sent duplicate commands to {category}")
        else:
            self.ui.add_log_message("TEST ERROR: Not connected")
    
    def run(self):
        """Run the simulator."""
        self.ui.add_log_message("Remote Controller Simulator started")
        self.ui.add_log_message("Configure MQTT connection and click Connect")
        self.root.mainloop()


def main():
    """Main entry point."""
    simulator = RemoteSimulator()
    simulator.run()


if __name__ == "__main__":
    main()
