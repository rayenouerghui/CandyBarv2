"""
Button Mapping and Input State Machine for Remote Controller Simulator

This module provides an isolated layer for mapping physical buttons to actions.
It allows easy modification once the real physical remote behavior is confirmed.

UNKNOWN BEHAVIORS:
- The four blue buttons' functions are not documented in the codebase
- Number entry behavior (immediate send vs confirm button) is unknown
- Delete/backspace mechanism is unknown
- Clear/reset mechanism is unknown
- Auto-padding behavior is unknown
- Maximum digit limit before auto-send is unknown

TODO: Update these mappings once physical remote behavior is confirmed.
"""

from enum import Enum
from typing import Callable, Optional


class ButtonAction(Enum):
    """Button action types."""
    CATEGORY_A = "category_a"
    CATEGORY_B = "category_b"
    CATEGORY_C = "category_c"
    CATEGORY_D = "category_d"
    DIGIT_0 = "digit_0"
    DIGIT_1 = "digit_1"
    DIGIT_2 = "digit_2"
    DIGIT_3 = "digit_3"
    DIGIT_4 = "digit_4"
    DIGIT_5 = "digit_5"
    DIGIT_6 = "digit_6"
    DIGIT_7 = "digit_7"
    DIGIT_8 = "digit_8"
    DIGIT_9 = "digit_9"
    BLUE_SEND = "blue_send"      # Top-right: Send number to display
    BLUE_RESET = "blue_reset"    # Mid-right: Reset display to 0
    BLUE_DELETE = "blue_delete"  # Bottom-right: Delete last digit
    BLUE_RESTART = "blue_restart"  # Bottom-center: Restart Qt display


class InputState(Enum):
    """Input state machine states."""
    IDLE = "idle"
    ENTERING = "entering"
    READY_TO_SEND = "ready_to_send"


class ButtonMapping:
    """
    Button mapping and input state machine.
    
    This class isolates button behavior from the UI, making it easy to
    modify once the physical remote behavior is confirmed.
    """
    
    def __init__(self):
        self.category = "A"
        self.display_value = "0000"
        self.input_buffer = ""
        self.state = InputState.IDLE
        self.max_digits = 4  # Physical remote has 4-digit display
        self.auto_pad = True  # TODO: UNCONFIRMED - does real remote auto-pad?
        self.auto_send = False  # TODO: UNCONFIRMED - does real remote auto-send?
        self.on_number_ready: Optional[Callable[[str, str], None]] = None
        self.on_display_update: Optional[Callable[[str], None]] = None
        self.on_category_change: Optional[Callable[[str], None]] = None
    
    def set_number_ready_callback(self, callback: Callable[[str, str], None]):
        """Set callback called when number is ready to send (category, number)."""
        self.on_number_ready = callback
    
    def set_display_update_callback(self, callback: Callable[[str], None]):
        """Set callback called when display should update."""
        self.on_display_update = callback
    
    def set_category_change_callback(self, callback: Callable[[str], None]):
        """Set callback called when category changes."""
        self.on_category_change = callback
    
    def handle_button(self, action: ButtonAction):
        """
        Handle a button press.
        
        Args:
            action: ButtonAction enum value
        """
        # Category buttons
        if action == ButtonAction.CATEGORY_A:
            self._set_category("A")
        elif action == ButtonAction.CATEGORY_B:
            self._set_category("B")
        elif action == ButtonAction.CATEGORY_C:
            self._set_category("C")
        elif action == ButtonAction.CATEGORY_D:
            self._set_category("D")
        
        # Digit buttons
        elif action == ButtonAction.DIGIT_0:
            self._append_digit("0")
        elif action == ButtonAction.DIGIT_1:
            self._append_digit("1")
        elif action == ButtonAction.DIGIT_2:
            self._append_digit("2")
        elif action == ButtonAction.DIGIT_3:
            self._append_digit("3")
        elif action == ButtonAction.DIGIT_4:
            self._append_digit("4")
        elif action == ButtonAction.DIGIT_5:
            self._append_digit("5")
        elif action == ButtonAction.DIGIT_6:
            self._append_digit("6")
        elif action == ButtonAction.DIGIT_7:
            self._append_digit("7")
        elif action == ButtonAction.DIGIT_8:
            self._append_digit("8")
        elif action == ButtonAction.DIGIT_9:
            self._append_digit("9")
        
        # Blue buttons
        elif action == ButtonAction.BLUE_SEND:
            self._send_number()
        elif action == ButtonAction.BLUE_RESET:
            self._reset_input()
        elif action == ButtonAction.BLUE_DELETE:
            self._delete_digit()
        elif action == ButtonAction.BLUE_RESTART:
            self._restart_display()
    
    def _set_category(self, category: str):
        """Set the category (A, B, C, D)."""
        if self.category != category:
            self.category = category
            self._reset_input()
            if self.on_category_change:
                self.on_category_change(category)
    
    def _append_digit(self, digit: str):
        """
        Append a digit to the input buffer.
        
        TODO: UNCONFIRMED - Real remote behavior unknown:
        - Does it send immediately on each digit?
        - Does it wait for confirm button?
        - Does it auto-pad with leading zeros?
        - Is there a max digit limit?
        
        Current implementation:
        - Appends digit to buffer
        - Updates display
        - Does NOT auto-send (requires manual trigger)
        - Does NOT auto-pad (shows raw input)
        """
        if len(self.input_buffer) < self.max_digits:
            self.input_buffer += digit
            self.state = InputState.ENTERING
            self._update_display()
            
            # TODO: UNCONFIRMED - Auto-send behavior
            # if self.auto_send and len(self.input_buffer) >= 3:
            #     self._send_number()
    
    def _delete_digit(self):
        """
        Delete last digit from input buffer.
        
        TODO: UNCONFIRMED - Which button performs this?
        """
        if self.input_buffer:
            self.input_buffer = self.input_buffer[:-1]
            self._update_display()
            if not self.input_buffer:
                self.state = InputState.IDLE
    
    def _reset_input(self):
        """Reset the input buffer and send '00|nosound' to display."""
        self.input_buffer = ""
        self.state = InputState.IDLE
        self._update_display()
        
        # Send reset command via MQTT with |nosound flag
        if self.on_number_ready:
            self.on_number_ready(self.category, "00|nosound")
    
    def _send_number(self):
        """
        Send the current number via MQTT.
        
        TODO: UNCONFIRMED - Which button triggers this?
        """
        if self.input_buffer:
            # Validate number (1-3 digits, max 999 per production rules)
            try:
                num_val = int(self.input_buffer)
                if 0 <= num_val <= 999:
                    if self.on_number_ready:
                        self.on_number_ready(self.category, self.input_buffer)
                    self.state = InputState.READY_TO_SEND
                else:
                    # Invalid number - reset
                    self._reset_input()
            except ValueError:
                self._reset_input()
    
    def _update_display(self):
        """Update the 4-digit display."""
        if self.input_buffer:
            # Show raw input with 2-digit minimum padding
            self.display_value = self.input_buffer.rjust(2, "0") if self.auto_pad else self.input_buffer.ljust(4, " ")
        else:
            self.display_value = "00"  # Reset to "00" with 2-digit padding
        
        if self.on_display_update:
            self.on_display_update(self.display_value)
    
    def _restart_display(self):
        """
        Restart the Qt display via HTTP POST to /api/restart.
        This sends a restart command to the CandyBar server.
        """
        import requests
        
        try:
            # Try to send restart command to CandyBar server
            response = requests.post(
                "http://localhost:8080/api/restart",
                timeout=5
            )
            if response.status_code == 200:
                print(f"[ButtonMapping] Restart command sent successfully")
            else:
                print(f"[ButtonMapping] Restart command failed: {response.status_code}")
        except Exception as e:
            print(f"[ButtonMapping] Restart command error: {e}")
            # Note: This is expected if CandyBar is not running or server is not accessible
    
    def _handle_unmapped(self, button_name: str):
        """Handle unmapped blue button press."""
        # TODO: Implement once physical remote behavior is confirmed
        # For now, log that this button is unmapped
        print(f"[ButtonMapping] UNMAPPED: {button_name} - behavior not yet confirmed")
    
    def force_send(self):
        """
        Force send the current number (for testing purposes).
        
        This is a convenience method for the developer panel to manually
        trigger a send without knowing which physical button does it.
        """
        self._send_number()
    
    def force_delete(self):
        """
        Force delete last digit (for testing purposes).
        
        This is a convenience method for the developer panel to manually
        trigger a delete without knowing which physical button does it.
        """
        self._delete_digit()
    
    def force_reset(self):
        """
        Force reset input (for testing purposes).
        
        This is a convenience method for the developer panel to manually
        trigger a reset without knowing which physical button does it.
        """
        self._reset_input()
