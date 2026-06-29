import QtQuick 2.15
import "global"

// ── ConnectionBanner ──────────────────────────────────────────────────────
// Shown when MQTT is disconnected. Small, unobtrusive pill at the bottom.
// Never replaces the display content — last known good state stays visible.

Item {
    id: root
    width: pill.width + 4
    height: pill.height + 4

    opacity: 0
    // Fades in/out when visible changes
    onVisibleChanged: {
        if (visible) {
            opacity = 0
            fade_in.start()
        } else {
            fade_out.start()
        }
    }

    NumberAnimation { id: fade_in;  target: root; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
    NumberAnimation { id: fade_out; target: root; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InCubic }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        radius: 20
        color: Qt.rgba(0, 0, 0, 0.65)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        width: row.implicitWidth + 24
        height: 32

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            // Pulsing dot
            Rectangle {
                width: 6; height: 6; radius: 3
                color: "#f59e0b"
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.visible
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: DisplayState.mqttStatus
                font.family: DisplayState.uiFont
                font.pixelSize: 12
                color: "#FFFFFF"
                opacity: 0.60
            }
        }
    }
}
