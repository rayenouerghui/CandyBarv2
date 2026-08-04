import QtQuick 2.15
import QtQuick.Controls 2.15
import FluentUI 1.0
import "global"

// ── MainDisplay ──────────────────────────────────────────────────────────
// Top-level single-screen item. Hosts:
//   1. DisplayView        (permanent display — Classic, Split, or Centered layout)
//   2. WelcomeSplash      (boot state — auto-advances after delay, crossfades out)
//   3. CustomerSiteQr     (always-visible glass card, bottom-right — links to official site)
//   4. ConnectionBanner   (reconnecting indicator — non-intrusive)
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

        onSplashComplete: {
            display_view.opacity = 1
            welcome.opacity = 0
        }

        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.InCubic }
        }
    }

    // ── 3. Customer site QR — bottom-right glass card ────────────────────
    // Always visible once welcome fades. Links to official CandyBarV2 site.
    CustomerSiteQrOverlay {
        id: site_qr
        anchors {
            right:        parent.right
            bottom:       parent.bottom
            rightMargin:  40
            bottomMargin: 100
        }
        opacity: welcome.opacity < 0.01 ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
    }

    // ── 4. Connection banner ─────────────────────────────────────────────
    ConnectionBanner {
        visible: false
    }
}
