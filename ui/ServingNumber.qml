import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"

Item {
    id: numberRoot
    property real layoutMult: 1.0
    property real numScale: 1.0
    property string shownNumber: DisplayState.currentNumber

    // Bindable animation properties from the display container
    property real rootOpacity: 1.0
    property real rootScale: 1.0
    property real rootTranslateY: 0.0

    implicitWidth:  numText.implicitWidth
    implicitHeight: numText.implicitHeight
    width:  implicitWidth
    height: implicitHeight

    opacity: rootOpacity
    scale:   rootScale
    transformOrigin: Item.Center
    transform: Translate { y: numberRoot.rootTranslateY }

    // Shadow offset for single shadow copy
    readonly property real shadowOffsetY: Math.max(numberRoot.numScale * 1.2, 1.5)

    // Single shadow copy (lightweight alternative to multi-ring shadow)
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: numberRoot.shadowOffsetY
        text: numberRoot.shownNumber
        font.family:        DisplayState.numberFont
        font.pixelSize:     Math.max(DisplayState.numberFontSize || (DisplayState.fontSize * numberRoot.numScale * layoutMult), 12)
        font.weight:        Font.Black
        font.letterSpacing: -3
        renderType:         Text.NativeRendering
        color: Qt.rgba(0.02, 0.02, 0.05, 0.08)
        z: -1
    }

    // Main text — sharp, on top, untouched by the shadow
    Text {
        id: numText
        anchors.centerIn: parent
        z: 10
        text: numberRoot.shownNumber
        font.family:       DisplayState.numberFont
        font.pixelSize:    Math.max(DisplayState.numberFontSize || (DisplayState.fontSize * numberRoot.numScale * layoutMult), 12)
        font.weight:       Font.Black
        font.letterSpacing: -3
        renderType:        Text.NativeRendering
        color:             DisplayState.numberColor
    }
}