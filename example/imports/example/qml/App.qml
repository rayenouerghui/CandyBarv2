import QtQuick 2.15
import QtQuick.Window 2.15
import FluentUI 1.0
import "global"

// ── CandyBarV2 root ──────────────────────────────────────────────────────
// Pure kiosk app — no routing, no navigation shell, one window, one view.

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    color: "#0b0d10"
    title: "CandyBarV2"

    // Force dark mode so FluentUI tokens read correctly
    Component.onCompleted: {
        FluTheme.darkMode = FluThemeType.DarkMode.Dark
        FluTheme.animationEnabled = true

        // Populate URLs from NetworkHelper
        DisplayState.publicUrl = NetworkHelper.publicUrl
        DisplayState.adminUrl  = NetworkHelper.adminUrl

        // Load persisted display settings from disk
        DisplayState.loadFromDisk()
    }

    // Mirror MQTT connection state into DisplayState
    Connections {
        target: MqttClient
        function onConnectedChanged()              { DisplayState.mqttConnected = MqttClient.connected }
        function onConnectionStatusChanged(status) { DisplayState.mqttStatus    = status }
        function onDisplayCommandReceived(key, val){ DisplayState.applyMqttCommand(key, val) }
    }

    // ── The single full-screen display item ─────────────────────────────
    MainDisplay {
        anchors.fill: parent
    }

    // ── Keyboard shortcuts (kiosk management) ────────────────────────────
    // Escape or Super+M → exit fullscreen to windowed (for maintenance)
    // Super+Q          → close the app
    Item {
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.showNormal()
                event.accepted = true
            } else if (event.key === Qt.Key_M && (event.modifiers & Qt.MetaModifier)) {
                root.showMinimized()
                event.accepted = true
            } else if (event.key === Qt.Key_Q && (event.modifiers & Qt.MetaModifier)) {
                Qt.quit()
                event.accepted = true
            }
        }
    }
}
