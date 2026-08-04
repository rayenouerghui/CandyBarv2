import QtQuick 2.15
import "global"

// ── ConnectionBanner ──────────────────────────────────────────────────────
// Shown when MQTT is disconnected. Bottom-centered status pill.
// Pill geometry from material-components-qml NodeGraphPage.qml (radius 14,
// padded label). Fade timing follows Snackbar asymmetric show/hide pattern.

Item {
    id: root

    readonly property int dur_micro: 150
    readonly property int dur_std:  300
    readonly property int dur_full: 600

    width: pill.width
    height: pill.height

    opacity: visible ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: visible ? root.dur_std : root.dur_micro
            easing.type: visible ? Easing.OutCubic : Easing.InCubic
        }
    }

    Rectangle {
        id: pill
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        width: row.implicitWidth + 26
        height: row.implicitHeight + 12

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 6; height: 6; radius: 3
                color: "#f59e0b"
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.visible
                    NumberAnimation { to: 0.35; duration: root.dur_full; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: root.dur_full; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: DisplayState.mqttStatus
                font.family: DisplayState.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: "#FFFFFF"
                opacity: 0.42
            }
        }
    }
}
