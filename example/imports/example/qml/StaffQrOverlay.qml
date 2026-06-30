import QtQuick 2.15
import FluentUI 1.0
import "global"

// ── StaffQrOverlay ────────────────────────────────────────────────────────
// Hidden by default. Recalled via corner tap or GPIO button.
// Appear/dismiss motion unchanged from prior pass (OutQuart in, InCubic out).
// Card chrome matches PublicQrOverlay; dismiss uses MMaterial MButton press opacity.

Item {
    id: root
    width: 188
    height: 236

    property int autoHideMs: 30000

    readonly property int pad: 14
    readonly property int qrSize: 120

    function recall() {
        scale_out.stop()
        root.scale   = 0.78
        root.opacity = 0
        scale_in.start()
        hide_timer.restart()
    }

    function dismiss() {
        scale_in.stop()
        scale_out.start()
        hide_timer.stop()
    }

    ParallelAnimation {
        id: scale_in
        NumberAnimation { target: root; property: "scale";   from: 0.78; to: 1.0; duration: 300; easing.type: Easing.OutQuart }
        NumberAnimation { target: root; property: "opacity"; from: 0;    to: 1;   duration: 300; easing.type: Easing.OutQuart }
    }

    ParallelAnimation {
        id: scale_out
        NumberAnimation { target: root; property: "scale";   from: 1.0; to: 0.78; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "opacity"; from: 1;   to: 0;    duration: 200; easing.type: Easing.InCubic }
    }

    Timer {
        id: hide_timer
        interval: root.autoHideMs
        repeat: false
        onTriggered: root.dismiss()
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.78)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Column {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.pad
            }
            spacing: 10

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "STAFF ADMIN"
                font.family: DisplayState.uiFont
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 1.4
                color: "#FFFFFF"
                opacity: 0.42
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.qrSize + 8
                height: root.qrSize + 8
                radius: 6
                color: "#FFFFFF"

                FluQRCode {
                    anchors.centerIn: parent
                    size: root.qrSize
                    text: DisplayState.adminUrl
                    color: "#000000"
                    bgColor: "#FFFFFF"
                    margins: 0
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Scan to open editor"
                font.family: DisplayState.uiFont
                font.pixelSize: 9
                color: "#FFFFFF"
                opacity: 0.30
            }

            Rectangle {
                id: dismiss_btn
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 32
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.07)
                opacity: dismiss_area.pressed ? 0.70 : 1.0

                Text {
                    anchors.centerIn: parent
                    text: "Dismiss"
                    font.family: DisplayState.uiFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: "#FFFFFF"
                    opacity: 0.55
                }

                MouseArea {
                    id: dismiss_area
                    anchors.fill: parent
                    onClicked: root.dismiss()
                }
            }
        }
    }
}
