"""
Remote Controller Simulator UI
Tkinter-based GUI that reproduces the physical Genical remote appearance
"""
import sys
import os
import tkinter as tk
from tkinter import ttk, scrolledtext
from typing import Callable, Optional

# Handle imports for both execution methods
try:
    from tools.remote_simulator.button_mapping import ButtonMapping, ButtonAction
except ImportError:
    from ..button_mapping import ButtonMapping, ButtonAction


class RemoteSimulatorUI:
    """Main UI for the remote controller simulator."""
    
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Genical Remote Controller Simulator")
        self.root.geometry("900x650")
        self.root.configure(bg="#2c2c2c")
        
        # Callbacks
        self.on_connect: Optional[Callable[[], None]] = None
        self.on_disconnect: Optional[Callable[[], None]] = None
        self.on_send_command: Optional[Callable[[str, str], None]] = None
        self.on_test_send_1: Optional[Callable[[], None]] = None
        self.on_test_send_10: Optional[Callable[[], None]] = None
        self.on_test_send_100: Optional[Callable[[], None]] = None
        self.on_test_rapid: Optional[Callable[[], None]] = None
        self.on_test_disconnect_reconnect: Optional[Callable[[], None]] = None
        self.on_test_invalid: Optional[Callable[[], None]] = None
        self.on_test_duplicate: Optional[Callable[[], None]] = None
        
        # State
        self.mqtt_connected = False
        self.selected_category = "A"
        self.display_value = "0000"
        
        # Button mapping
        try:
            self.button_mapping = ButtonMapping()
            self.button_mapping.set_display_update_callback(self._update_display)
            self.button_mapping.set_category_change_callback(self._update_category)
            self.button_mapping.set_number_ready_callback(self._on_number_ready)
        except Exception as e:
            print(f"Error initializing button mapping: {e}")
            import traceback
            traceback.print_exc()
        
        try:
            self._setup_ui()
        except Exception as e:
            print(f"Error setting up UI: {e}")
            import traceback
            traceback.print_exc()
    
    def _setup_ui(self):
        """Setup the main UI layout."""
        # Main container
        main_frame = tk.Frame(self.root, bg="#2c2c2c")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Left side: Physical remote
        remote_frame = tk.Frame(main_frame, bg="#1a1a1a", relief=tk.RAISED, bd=3)
        remote_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=False, padx=10, pady=10)
        
        self._build_physical_remote(remote_frame)
        
        # Right side: Developer panel (collapsible)
        dev_frame = tk.Frame(main_frame, bg="#2c2c2c")
        dev_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        self._build_developer_panel(dev_frame)
    
    def _build_physical_remote(self, parent: tk.Frame):
        """Build the physical remote UI."""
        # Remote body
        remote_body = tk.Frame(parent, bg="#0d0d0d", width=280, height=450)
        remote_body.pack(padx=10, pady=10, ipadx=10, ipady=10)
        remote_body.pack_propagate(False)
        
        # GENICAL label
        tk.Label(
            remote_body,
            text="GENICAL",
            bg="#0d0d0d",
            fg="#ffffff",
            font=("Arial", 12, "bold")
        ).pack(pady=(10, 5))
        
        # 4-digit display
        display_frame = tk.Frame(remote_body, bg="#000000", relief=tk.SUNKEN, bd=2)
        display_frame.pack(pady=5)
        
        self.display_label = tk.Label(
            display_frame,
            text="0000",
            bg="#000000",
            fg="#00ff00",  # Green LED color
            font=("Courier New", 24, "bold"),
            width=4
        )
        self.display_label.pack(padx=10, pady=5)
        
        # Button grid
        button_frame = tk.Frame(remote_body, bg="#0d0d0d")
        button_frame.pack(pady=10)
        
        # Category buttons (left column)
        category_frame = tk.Frame(button_frame, bg="#0d0d0d")
        category_frame.pack(side=tk.LEFT, padx=5)
        
        for cat in ["D", "C", "B", "A"]:
            btn = tk.Button(
                category_frame,
                text=cat,
                bg="#333333",
                fg="#ffffff",
                font=("Arial", 10, "bold"),
                width=3,
                height=2,
                command=lambda c=cat: self._on_category_button(c)
            )
            btn.pack(pady=2)
        
        # Numeric keypad (center)
        keypad_frame = tk.Frame(button_frame, bg="#0d0d0d")
        keypad_frame.pack(side=tk.LEFT, padx=5)
        
        keypad_layout = [
            ["7", "8", "9"],
            ["4", "5", "6"],
            ["1", "2", "3"],
            ["0"]
        ]
        
        for row in keypad_layout:
            row_frame = tk.Frame(keypad_frame, bg="#0d0d0d")
            row_frame.pack()
            for digit in row:
                btn = tk.Button(
                    row_frame,
                    text=digit,
                    bg="#444444",
                    fg="#ffffff",
                    font=("Arial", 12, "bold"),
                    width=3,
                    height=2,
                    command=lambda d=digit: self._on_digit_button(d)
                )
                btn.pack(side=tk.LEFT, padx=1, pady=1)
        
        # Blue function buttons (right column)
        blue_frame = tk.Frame(button_frame, bg="#0d0d0d")
        blue_frame.pack(side=tk.LEFT, padx=5)
        
        # 3 blue buttons in vertical layout with function labels
        blue_buttons = [
            ("SEND", 0),   # Top-right: Send number
            ("RST", 1),    # Mid-right: Reset display
            ("DEL", 2),    # Bottom-right: Delete digit
        ]
        
        for label, idx in blue_buttons:
            btn = tk.Button(
                blue_frame,
                text=label,
                bg="#0066cc",
                fg="#ffffff",
                font=("Arial", 9, "bold"),
                width=3,
                height=2,
                command=lambda i=idx: self._on_blue_button(i)
            )
            btn.pack(pady=2)
        
        # Extra blue button next to 0 (bottom center) - Restart
        tk.Button(
            keypad_frame,
            text="MAJ",  # Abbreviation for "mise à jour"
            bg="#0066cc",
            fg="#ffffff",
            font=("Arial", 8, "bold"),
            width=3,
            height=2,
            command=lambda: self._on_blue_button(4)
        ).pack(side=tk.LEFT, padx=1, pady=1)
    
    def _build_developer_panel(self, parent: tk.Frame):
        """Build the developer/test panel."""
        # Header with collapse button
        header_frame = tk.Frame(parent, bg="#2c2c2c")
        header_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(
            header_frame,
            text="Developer / Test Panel",
            bg="#2c2c2c",
            fg="#ffffff",
            font=("Arial", 12, "bold")
        ).pack(side=tk.LEFT)
        
        self.dev_panel_visible = tk.BooleanVar(value=True)
        collapse_btn = tk.Button(
            header_frame,
            text="▼",
            bg="#444444",
            fg="#ffffff",
            width=3,
            command=self._toggle_dev_panel
        )
        collapse_btn.pack(side=tk.RIGHT)
        
        # Collapsible content
        self.dev_content = tk.Frame(parent, bg="#2c2c2c")
        self.dev_content.pack(fill=tk.BOTH, expand=True)
        
        # Connection settings
        conn_frame = tk.LabelFrame(
            self.dev_content,
            text="MQTT Connection",
            bg="#2c2c2c",
            fg="#ffffff"
        )
        conn_frame.pack(fill=tk.X, pady=5)
        
        # Host
        tk.Label(conn_frame, text="Host:", bg="#2c2c2c", fg="#ffffff").grid(row=0, column=0, sticky=tk.W, padx=5, pady=2)
        self.host_entry = tk.Entry(conn_frame, bg="#444444", fg="#ffffff", insertbackground="#ffffff")
        self.host_entry.insert(0, "localhost")
        self.host_entry.grid(row=0, column=1, padx=5, pady=2)
        
        # Port
        tk.Label(conn_frame, text="Port:", bg="#2c2c2c", fg="#ffffff").grid(row=0, column=2, sticky=tk.W, padx=5, pady=2)
        self.port_entry = tk.Entry(conn_frame, bg="#444444", fg="#ffffff", insertbackground="#ffffff", width=8)
        self.port_entry.insert(0, "1883")
        self.port_entry.grid(row=0, column=3, padx=5, pady=2)
        
        # Username
        tk.Label(conn_frame, text="User:", bg="#2c2c2c", fg="#ffffff").grid(row=1, column=0, sticky=tk.W, padx=5, pady=2)
        self.user_entry = tk.Entry(conn_frame, bg="#444444", fg="#ffffff", insertbackground="#ffffff")
        self.user_entry.grid(row=1, column=1, padx=5, pady=2)
        
        # Password
        tk.Label(conn_frame, text="Pass:", bg="#2c2c2c", fg="#ffffff").grid(row=1, column=2, sticky=tk.W, padx=5, pady=2)
        self.pass_entry = tk.Entry(conn_frame, bg="#444444", fg="#ffffff", insertbackground="#ffffff", show="*", width=8)
        self.pass_entry.grid(row=1, column=3, padx=5, pady=2)
        
        # Connect/Disconnect buttons
        btn_frame = tk.Frame(conn_frame, bg="#2c2c2c")
        btn_frame.grid(row=2, column=0, columnspan=4, pady=5)
        
        self.connect_btn = tk.Button(
            btn_frame,
            text="Connect",
            bg="#00aa00",
            fg="#ffffff",
            width=10,
            command=self._on_connect
        )
        self.connect_btn.pack(side=tk.LEFT, padx=5)
        
        self.disconnect_btn = tk.Button(
            btn_frame,
            text="Disconnect",
            bg="#aa0000",
            fg="#ffffff",
            width=10,
            command=self._on_disconnect,
            state=tk.DISABLED
        )
        self.disconnect_btn.pack(side=tk.LEFT, padx=5)
        
        # Status
        self.status_label = tk.Label(
            conn_frame,
            text="Status: Disconnected",
            bg="#2c2c2c",
            fg="#ff0000",
            font=("Arial", 10, "bold")
        )
        self.status_label.grid(row=3, column=0, columnspan=4, pady=5)
        
        # Category display
        cat_frame = tk.LabelFrame(
            self.dev_content,
            text="Selected Category",
            bg="#2c2c2c",
            fg="#ffffff"
        )
        cat_frame.pack(fill=tk.X, pady=5)
        
        self.category_label = tk.Label(
            cat_frame,
            text="A",
            bg="#2c2c2c",
            fg="#00ff00",
            font=("Arial", 16, "bold")
        )
        self.category_label.pack(pady=5)
        
        # Message log
        log_frame = tk.LabelFrame(
            self.dev_content,
            text="MQTT Message Log",
            bg="#2c2c2c",
            fg="#ffffff"
        )
        log_frame.pack(fill=tk.BOTH, expand=True, pady=5)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            bg="#1a1a1a",
            fg="#00ff00",
            font=("Courier New", 9),
            height=10
        )
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        clear_log_btn = tk.Button(
            log_frame,
            text="Clear Log",
            bg="#444444",
            fg="#ffffff",
            command=self._clear_log
        )
        clear_log_btn.pack(pady=2)
        
        # Test tools
        test_frame = tk.LabelFrame(
            self.dev_content,
            text="Test Tools",
            bg="#2c2c2c",
            fg="#ffffff"
        )
        test_frame.pack(fill=tk.X, pady=5)
        
        test_buttons = [
            ("Send 1", self._on_test_send_1),
            ("Send 10", self._on_test_send_10),
            ("Send 100", self._on_test_send_100),
            ("Rapid Press", self._on_test_rapid),
            ("Disconnect/Reconnect", self._on_test_disconnect_reconnect),
            ("Invalid Payload", self._on_test_invalid),
            ("Duplicate Command", self._on_test_duplicate),
        ]
        
        for i, (text, callback) in enumerate(test_buttons):
            btn = tk.Button(
                test_frame,
                text=text,
                bg="#444444",
                fg="#ffffff",
                width=15,
                command=callback
            )
            btn.grid(row=i//2, column=i%2, padx=5, pady=2)
        
        # Manual controls (for testing unmapped behaviors)
        manual_frame = tk.LabelFrame(
            self.dev_content,
            text="Manual Controls (Testing)",
            bg="#2c2c2c",
            fg="#ffffff"
        )
        manual_frame.pack(fill=tk.X, pady=5)
        
        tk.Button(
            manual_frame,
            text="Force Send",
            bg="#0066cc",
            fg="#ffffff",
            command=self._on_force_send
        ).pack(side=tk.LEFT, padx=5, pady=5)
        
        tk.Button(
            manual_frame,
            text="Force Delete",
            bg="#0066cc",
            fg="#ffffff",
            command=self._on_force_delete
        ).pack(side=tk.LEFT, padx=5, pady=5)
        
        tk.Button(
            manual_frame,
            text="Force Reset",
            bg="#0066cc",
            fg="#ffffff",
            command=self._on_force_reset
        ).pack(side=tk.LEFT, padx=5, pady=5)
    
    def _toggle_dev_panel(self):
        """Toggle developer panel visibility."""
        if self.dev_panel_visible.get():
            self.dev_content.pack_forget()
            self.dev_panel_visible.set(False)
        else:
            self.dev_content.pack(fill=tk.BOTH, expand=True)
            self.dev_panel_visible.set(True)
    
    def _on_category_button(self, category: str):
        """Handle category button press."""
        action_map = {
            "A": ButtonAction.CATEGORY_A,
            "B": ButtonAction.CATEGORY_B,
            "C": ButtonAction.CATEGORY_C,
            "D": ButtonAction.CATEGORY_D,
        }
        self.button_mapping.handle_button(action_map[category])
    
    def _on_digit_button(self, digit: str):
        """Handle digit button press."""
        action_map = {
            "0": ButtonAction.DIGIT_0,
            "1": ButtonAction.DIGIT_1,
            "2": ButtonAction.DIGIT_2,
            "3": ButtonAction.DIGIT_3,
            "4": ButtonAction.DIGIT_4,
            "5": ButtonAction.DIGIT_5,
            "6": ButtonAction.DIGIT_6,
            "7": ButtonAction.DIGIT_7,
            "8": ButtonAction.DIGIT_8,
            "9": ButtonAction.DIGIT_9,
        }
        self.button_mapping.handle_button(action_map[digit])
    
    def _on_blue_button(self, index: int):
        """Handle blue button press."""
        action_map = {
            0: ButtonAction.BLUE_SEND,      # Top-right: Send
            1: ButtonAction.BLUE_RESET,     # Mid-right: Reset display
            2: ButtonAction.BLUE_DELETE,   # Bottom-right: Delete
            4: ButtonAction.BLUE_RESTART,  # Bottom-center: Restart
        }
        if index in action_map:
            self.button_mapping.handle_button(action_map[index])
    
    def _on_connect(self):
        """Handle connect button."""
        if self.on_connect:
            self.on_connect()
    
    def _on_disconnect(self):
        """Handle disconnect button."""
        if self.on_disconnect:
            self.on_disconnect()
    
    def _on_number_ready(self, category: str, number: str):
        """Handle number ready to send."""
        if self.on_send_command:
            self.on_send_command(category, number)
    
    def _on_force_send(self):
        """Force send current number (testing)."""
        self.button_mapping.force_send()
    
    def _on_force_delete(self):
        """Force delete last digit (testing)."""
        self.button_mapping.force_delete()
    
    def _on_force_reset(self):
        """Force reset input (testing)."""
        self.button_mapping.force_reset()
    
    def _on_test_send_1(self):
        """Test: Send 1 command."""
        if self.on_test_send_1:
            self.on_test_send_1()
    
    def _on_test_send_10(self):
        """Test: Send 10 commands."""
        if self.on_test_send_10:
            self.on_test_send_10()
    
    def _on_test_send_100(self):
        """Test: Send 100 commands."""
        if self.on_test_send_100:
            self.on_test_send_100()
    
    def _on_test_rapid(self):
        """Test: Rapid button presses."""
        if self.on_test_rapid:
            self.on_test_rapid()
    
    def _on_test_disconnect_reconnect(self):
        """Test: Disconnect and reconnect."""
        if self.on_test_disconnect_reconnect:
            self.on_test_disconnect_reconnect()
    
    def _on_test_invalid(self):
        """Test: Invalid payload."""
        if self.on_test_invalid:
            self.on_test_invalid()
    
    def _on_test_duplicate(self):
        """Test: Duplicate command."""
        if self.on_test_duplicate:
            self.on_test_duplicate()
    
    def _update_display(self, value: str):
        """Update the 4-digit display."""
        self.display_value = value
        self.display_label.config(text=value)
    
    def _update_category(self, category: str):
        """Update the selected category display."""
        self.selected_category = category
        self.category_label.config(text=category)
    
    def _clear_log(self):
        """Clear the message log."""
        self.log_text.delete(1.0, tk.END)
    
    def add_log_message(self, message: str):
        """Add a message to the log."""
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
    
    def set_connection_status(self, connected: bool):
        """Update connection status display."""
        self.mqtt_connected = connected
        if connected:
            self.status_label.config(text="Status: Connected", fg="#00ff00")
            self.connect_btn.config(state=tk.DISABLED)
            self.disconnect_btn.config(state=tk.NORMAL)
        else:
            self.status_label.config(text="Status: Disconnected", fg="#ff0000")
            self.connect_btn.config(state=tk.NORMAL)
            self.disconnect_btn.config(state=tk.DISABLED)
    
    def get_connection_config(self):
        """Get connection configuration from UI."""
        return {
            "host": self.host_entry.get(),
            "port": int(self.port_entry.get()),
            "username": self.user_entry.get() or None,
            "password": self.pass_entry.get() or None,
        }
