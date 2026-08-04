import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"

Item {
    id: underlineRoot
    property real layoutMult: 1.0
    property real numScale: 1.0
    property color accentColor: DisplayState.accentColor

    // Bindable animation properties from the display container
    property real rootOpacity: 1.0
    property real rootScale: 1.0
    property real rootTranslateY: 0.0

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth:  glow.width
    Layout.preferredHeight: glow.height
    opacity: rootOpacity
    scale:   rootScale
    transformOrigin: Item.Center
    transform: Translate { y: underlineRoot.rootTranslateY }

    // Soft glow layer behind the bar — wider + softer, boosts perceived
    // contrast without changing the bar's crisp shape.
    Rectangle {
        id: glow
        anchors.centerIn: parent
        width:  bar.width + 24
        height: 14
        radius: height / 2
        color: Qt.rgba(underlineRoot.accentColor.r, underlineRoot.accentColor.g, underlineRoot.accentColor.b, 0.35)
    }

    Rectangle {
        id: bar
        anchors.centerIn: parent
        width:  Math.max(56, DisplayState.fontSize * underlineRoot.numScale * layoutMult * 0.46)
        height: 8
        radius: 4
        color: DisplayState.accentGradientEnabled ? "transparent" : underlineRoot.accentColor
        gradient: DisplayState.accentGradientEnabled ? accentGrad : null
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.35)
        Gradient {
            id: accentGrad
            orientation: DisplayState.accentGradientDirection === "top-to-bottom"
                         ? Gradient.Vertical : Gradient.Horizontal
            // Tapers to a dimmed version of the accent color instead of
            // full transparency, so the bar never has an invisible end.
            GradientStop { position: 0.0; color: underlineRoot.accentColor }
            GradientStop { position: 1.0; color: Qt.rgba(underlineRoot.accentColor.r, underlineRoot.accentColor.g, underlineRoot.accentColor.b, 0.35) }
        }
        Behavior on color { ColorAnimation { duration: 600 } }
    }
}
