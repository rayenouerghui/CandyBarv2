import QtQuick 2.15
import FluentUI 1.0
import "global"

// ── StaffQrOverlay ────────────────────────────────────────────────────────
// Hidden by default. Recalled via corner tap or GPIO button.
// Fades + scales in (ease-out), out (ease-in).
// Auto-hides after autoHideMs milliseconds.

Item {
    id: root
    width: 180
    height: 220

    property int autoHideMs: 30000   // 30s auto-hide

    // Public recall function — called by MainDisplay on tap or GPIO
    function recall() {
        scale_out.stop()
        root.scale    = 0.78   // C: wider origin range → overlay materialises from background
        root.opacity  = 0
        scale_in.start()
        hide_timer.restart()
    }

    function dismiss() {
        scale_in.stop()
        scale_out.start()
        hide_timer.stop()
    }

    // Appear: scale 0.78→1.0, opacity 0→1, OutQuart 300ms
    // A: OutQuart (steeper deceleration) → decisive tap response
    // C: from 0.78 (was 0.88) → wider range, overlay feels like it materialises
    ParallelAnimation {
        id: scale_in
        NumberAnimation { target: root; property: "scale";   from: 0.78; to: 1.0; duration: 300; easing.type: Easing.OutQuart }
        NumberAnimation { target: root; property: "opacity"; from: 0;    to: 1;   duration: 300; easing.type: Easing.OutQuart }
    }

    // Dismiss: scale 1.0→0.78, opacity 1→0, InCubic 200ms
    // Dismiss stays InCubic — leaving is calm, not urgent
    ParallelAnimation {
        id: scale_out
        NumberAnimation { target: root; property: "scale";   from: 1.0; to: 0.78; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "opacity"; from: 1;   to: 0;    duration: 200; easing.type: Easing.InCubic }
    }

    // Auto-hide timer
    Timer {
        id: hide_timer
        interval: root.autoHideMs
        repeat: false
        onTriggered: root.dismiss()
    }

    // Card
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0, 0, 0, 0.78)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Column {
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                margins: 12
            }
            spacing: 8

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Staff Admin"
                font.family: DisplayState.uiFont
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "#FFFFFF"
                opacity: 0.80
            }

            FluQRCode {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 128
                text: DisplayState.adminUrl
                color: "#000000"
                bgColor: "#FFFFFF"
                margins: 0
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: DisplayState.adminUrl
                font.family: DisplayState.uiFont
                font.pixelSize: 8
                color: "#FFFFFF"
                opacity: 0.35
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            // Dismiss button
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 4
                height: 30
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.07)

                Text {
                    anchors.centerIn: parent
                    text: "Dismiss"
                    font.family: DisplayState.uiFont
                    font.pixelSize: 11
                    color: "#FFFFFF"
                    opacity: 0.55
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismiss()
                }
            }
        }
    }
}
