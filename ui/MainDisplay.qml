import QtQuick 2.15
import QtQuick.Controls 2.15
import "global"

// ── MainDisplay ──────────────────────────────────────────────────────────
// Top-level single-screen item. Hosts:
//   1. DisplayView (permanent display — Split1, Split2, or Centered layout)
//
// Staff admin access: via direct URL printed to console on startup.
// No admin QR on the display — this screen is customer-facing only.

Item {
    id: root
    anchors.fill: parent

    // ── Permanent display (always loaded) ──────────────────
    DisplayView {
        id: display_view
        anchors.fill: parent
        opacity: 1
    }
}