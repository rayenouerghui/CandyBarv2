import QtQuick 6.2
import QtQuick.Layouts 6.2
import "global"

// Cadre (Frame) component that wraps display elements with a premium, high-end style
// Supports styles: glass (liquid glass iPhone), dark (premium dark slate), custom (custom color picker)
Item {
    id: cadreRoot

    // Properties controlled by DisplayState
    property bool cadreEnabled: DisplayState.cadreEnabled
    property string cadreType: "glass"  // "glass" | "dark" | "custom" | "none"
    property real cadreOpacity: 0.85
    property real cadreBlur: 32
    property real cornerRadius: 24
    property real borderWidth: 1.5
    property real padding: 32

    // Internal properties
    readonly property bool isGlass: cadreType === "glass"
    readonly property bool isDark: cadreType === "dark"
    readonly property bool isCustom: cadreType === "custom"
    readonly property bool isEnabled: cadreEnabled && cadreType !== "none"

    // Visuals container that has the opacity applied to it
    Item {
        id: cadreVisuals
        anchors.fill: parent
        opacity: cadreRoot.isEnabled ? Math.max(0.0, Math.min(1.0, cadreRoot.cadreOpacity)) : 0.0
        visible: cadreRoot.isEnabled
        z: 0

        // Outer Rectangle - simplified border (no live blur or shader effects)
        Rectangle {
            id: outerBorderRect
            anchors.fill: parent
            radius: cadreRoot.cornerRadius
            color: "transparent"
            // Simple border color: use accent/darker tones but keep it flat
            border.width: cadreRoot.borderWidth
            border.color: cadreRoot.isCustom ? DisplayState.cadreColor : (cadreRoot.isDark ? Qt.rgba(0,0,0,0.45) : Qt.rgba(1,1,1,0.12))

            // Inner Rectangle - Masked to preserve the border width
            Rectangle {
                id: innerBgRect
                anchors.fill: parent
                anchors.margins: cadreRoot.borderWidth
                radius: cadreRoot.cornerRadius - cadreRoot.borderWidth

                color: cadreRoot.isCustom ? DisplayState.cadreColor : (cadreRoot.isDark ? "#0E1116" : Qt.rgba(12,14,18,0.45))
                // No gloss, no highlight, no decorative accents — keep surface flat for performance
            }
        }
    }

    // Content container - children are safely mounted inside this padded area
    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: cadreRoot.padding
        z: 10
    }

    // Smooth entry transition
    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
}
