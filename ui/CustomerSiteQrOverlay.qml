import QtQuick 2.15
import FluentUI 1.0
import "global"

// ── CustomerSiteQrOverlay ─────────────────────────────────────────────────
// Single QR code on the display screen. Bottom-right corner, always visible
// after the welcome splash.
//
// Destination: DisplayState.siteUrl  (CANDYBAR_SITE_URL = "https://candybarv2.app")
//
// Visual spec — iOS frosted-glass / notification-card feel:
//   Card background : white at 15% opacity  (frosted, NOT a solid dark panel)
//   Card border     : 1px white at 28% opacity
//   Card radius     : 20px
//   No live backdrop-blur (ARM-safe): the white fill + low opacity gives the
//                    correct airy impression without ShaderEffect cost.
//   QR pad          : white #FFFFFF rectangle, 8px inset from card edge,
//                     radius 8px  — guarantees scan contrast on any background
//   Label           : "Visit our website", 50% white opacity, size 9px

Item {
    id: root

    // Card dimensions — compact but scannable
    width:  108
    height: 132

    readonly property int _radius:   20
    readonly property int _pad:       8
    readonly property int _qrSize:   72   // px — comfortable phone scan distance

    // ── Glass card ────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        radius:        root._radius
        color:         Qt.rgba(1, 1, 1, 0.16)   // white 16% — frosted glass base
        border.width:  1
        border.color:  Qt.rgba(1, 1, 1, 0.28)   // white 28% — subtle rim light

        // Inner highlight strip at top — adds the iOS "glass edge" illusion
        // without any live shader
        Rectangle {
            anchors {
                top:        parent.top
                left:       parent.left
                right:      parent.right
                topMargin:  1
                leftMargin: 6
                rightMargin: 6
            }
            height: 1
            radius: root._radius
            color:  Qt.rgba(1, 1, 1, 0.45)    // bright top rim
        }
    }

    // ── Content column ────────────────────────────────────────────────────
    Column {
        anchors {
            fill:    parent
            margins: root._pad
        }
        spacing: 6

        // ── White QR pad — black QR on white background for scan reliability ──
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width:  root._qrSize + 8
            height: root._qrSize + 8
            radius: 8
            color:  "#FFFFFF"

            FluQRCode {
                anchors.centerIn: parent
                size:    root._qrSize
                text:    DisplayState.siteUrl
                color:   "#000000"
                bgColor: "#FFFFFF"
                margins: 0
            }
        }

        // ── Label ─────────────────────────────────────────────────────────
        Text {
            width:               parent.width
            horizontalAlignment: Text.AlignHCenter
            text:                DisplayState.tr("visit_website")
            font.family:         DisplayState.uiFont
            font.pixelSize:      9
            font.weight:         Font.Medium
            color:               "#FFFFFF"
            opacity:             0.50
        }
    }
}
