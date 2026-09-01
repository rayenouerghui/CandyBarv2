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
    Layout.preferredWidth:  bar.width
    Layout.preferredHeight: bar.height
    opacity: rootOpacity
    scale:   rootScale
    transformOrigin: Item.Center
    transform: Translate { y: underlineRoot.rootTranslateY }

    // Single clean line — width scales with the number above it,
    // color matches the accent, no glow/gradient/border.
    Rectangle {
        id: bar
        anchors.centerIn: parent
        width:  Math.max(48, DisplayState.fontSize * underlineRoot.numScale * layoutMult * 0.32)
        height: 3
        radius: height / 2
        color: underlineRoot.accentColor
        opacity: 0.75
    }
}