import QtQuick 2.15
import QtQuick.Controls 2.15
import "global"

// ── MainDisplay ──────────────────────────────────────────────────────────
// Top-level single-screen item. Hosts:
//   1. DisplayView        (permanent display — Classic, Split, or Centered layout)
//   2. ConnectionBanner   (reconnecting indicator — non-intrusive)
//
// Staff admin access: via direct URL printed to console on startup.
// No admin QR on the display — this screen is customer-facing only.

Item {
    id: root
    anchors.fill: parent

    // ── 1. Permanent display (always loaded) ──────────────────
    DisplayView {
        id: display_view
        anchors.fill: parent
        opacity: 1
    }

    // ── 2. Connection banner ─────────────────────────────────────────────
    ConnectionBanner {
        visible: false
    }
}
