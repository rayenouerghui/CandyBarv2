import QtQuick 2.15
import QtQuick.Controls 2.15
import "global"

// ── MainDisplay ──────────────────────────────────────────────────────────
// Top-level single-screen item. Hosts:
//   1. DisplayView        (permanent display — Classic, Split, or Centered layout)
//   2. WelcomeSplash      (boot state — auto-advances after delay, crossfades out)
//   3. ConnectionBanner   (reconnecting indicator — non-intrusive)
//
// Staff admin access: via direct URL printed to console on startup.
// No admin QR on the display — this screen is customer-facing only.

Item {
    id: root
    anchors.fill: parent

    // ── 1. Permanent display (always loaded underneath) ──────────────────
    DisplayView {
        id: display_view
        anchors.fill: parent
        opacity: 0
        // Behavior on opacity {
        //     NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        // }
    }

    // ── 2. Welcome splash (boot state) ───────────────────────────────────
    WelcomeSplash {
        id: welcome
        anchors.fill: parent
        opacity: 1
        visible: opacity > 0

        onSplashComplete: {
            display_view.opacity = 1
            welcome.opacity = 0
        }

        // Behavior on opacity {
        //     NumberAnimation { duration: 600; easing.type: Easing.InCubic }
        // }
    }

    // ── 3. Connection banner ─────────────────────────────────────────────
    ConnectionBanner {
        visible: false
    }
}
