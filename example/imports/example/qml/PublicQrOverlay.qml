import QtQuick 2.15
import FluentUI 1.0
import "global"

// ── PublicQrOverlay ───────────────────────────────────────────────────────
// Always-visible small QR in the bottom-left corner.
// Links to the public read-only tracking page.
// Compact (96px QR) so it doesn't compete with the number for visual weight.

Item {
    id: root
    width: 128
    height: 156

    // Frosted card
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
    }

    Column {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 6

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Track your queue"
            font.family: DisplayState.uiFont
            font.pixelSize: 10
            color: "#FFFFFF"
            opacity: 0.55
        }

        FluQRCode {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 96
            text: DisplayState.publicUrl
            color: "#000000"
            bgColor: "#FFFFFF"
            margins: 0
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: DisplayState.publicUrl
            font.family: DisplayState.uiFont
            font.pixelSize: 8
            color: "#FFFFFF"
            opacity: 0.35
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            maximumLineCount: 2
        }
    }
}
