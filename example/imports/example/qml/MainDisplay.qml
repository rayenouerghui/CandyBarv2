import QtQuick 2.15
import QtQuick.Controls 2.15
import "global"

// ── MainDisplay ──────────────────────────────────────────────────────────
// Top-level single-screen item. Hosts:
//   1. WelcomeSplash (boot state — auto-advances after delay, crossfades out)
//   2. DisplayView   (permanent display — Classic or Split layout)
//   3. PublicQrOverlay  (always visible small corner element)
//   4. StaffQrOverlay   (recalled on demand, auto-hides)
//   5. ConnectionBanner (reconnecting indicator — non-intrusive)

Item {
    id: root
    anchors.fill: parent

    // ── 1. Permanent display (always loaded underneath) ──────────────────
    DisplayView {
        id: display_view
        anchors.fill: parent
        opacity: 0
        // Fades in when welcome finishes
        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }

    // ── 2. Welcome splash (boot state) ───────────────────────────────────
    WelcomeSplash {
        id: welcome
        anchors.fill: parent
        opacity: 1
        visible: opacity > 0

        // After splash duration, crossfade into display
        onSplashComplete: {
            display_view.opacity = 1
            welcome.opacity = 0
        }

        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.InCubic }
        }
    }

    // ── 3. Public QR overlay — always-visible corner element ─────────────
    PublicQrOverlay {
        id: public_qr
        anchors {
            left:         parent.left
            bottom:       parent.bottom
            leftMargin:   24
            bottomMargin: 24
        }
        // Only show once welcome is gone
        opacity: welcome.opacity < 0.01 ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // ── 4. Staff QR overlay — recalled on demand ─────────────────────────
    StaffQrOverlay {
        id: staff_qr
        anchors {
            right:        parent.right
            bottom:       parent.bottom
            rightMargin:  24
            bottomMargin: 24
        }
        visible: opacity > 0
        opacity: 0
        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // ── 5. Invisible corner tap target for recalling staff QR ────────────
    // 48×48 touch target, bottom-right corner — unobtrusive
    MouseArea {
        id: staff_tap
        anchors { right: parent.right; top: parent.top }
        width: 60; height: 60
        z: 100
        onClicked: staff_qr.recall()
    }

    // ── 6. GPIO button stub ──────────────────────────────────────────────
    // To wire a physical button: connect a GPIO input signal here.
    // Replace the comment with one line, e.g.:
    //   Connections { target: GpioButton; function onPressed() { staff_qr.recall() } }
    // GpioButton would be a Python QObject exposed as a context property.

    // ── 7. Connection banner ─────────────────────────────────────────────
    ConnectionBanner {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 32 }
        visible: !DisplayState.mqttConnected && welcome.opacity < 0.01
    }
}
