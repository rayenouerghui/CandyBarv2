import QtQuick 2.15
import FluentUI 1.0
import "global"

// ── PublicQrOverlay ───────────────────────────────────────────────────────
// Always-visible small QR in the bottom-left corner.
// Card chrome follows material-components-qml Card.qml (radius 12, 1px border,
// 16px padding rhythm) adapted to the dark kiosk surface system.

Item {
    id: root
    width: 136
    height: 168

    readonly property int pad: 14
    readonly property int qrSize: 88

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
    }

    Column {
        anchors {
            fill: parent
            margins: root.pad
        }
        spacing: 8

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "TRACK YOUR QUEUE"
            font.family: DisplayState.uiFont
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 1.2
            color: "#FFFFFF"
            opacity: 0.42
        }

        // QR on white pad — improves scan contrast and matches physical sticker affordance
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.qrSize + 8
            height: root.qrSize + 8
            radius: 6
            color: "#FFFFFF"

            FluQRCode {
                anchors.centerIn: parent
                size: root.qrSize
                text: DisplayState.publicUrl
                color: "#000000"
                bgColor: "#FFFFFF"
                margins: 0
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Scan to follow live"
            font.family: DisplayState.uiFont
            font.pixelSize: 9
            color: "#FFFFFF"
            opacity: 0.30
        }
    }
}
