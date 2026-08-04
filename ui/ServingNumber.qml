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

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth:  numText.implicitWidth
    Layout.preferredHeight: numText.implicitHeight
    
    opacity: rootOpacity
    scale:   rootScale
    transformOrigin: Item.Center
    transform: Translate { y: numberRoot.rootTranslateY }

    // Single shadow for performance
    Text {
        anchors.centerIn: parent
        text: numberRoot.shownNumber
        font.family:       DisplayState.numberFont
        font.pixelSize:    Math.max(DisplayState.numberFontSize || (DisplayState.fontSize * numberRoot.numScale * layoutMult), 12)
        font.weight:       Font.Black
        font.letterSpacing: -3
        renderType:        Text.NativeRendering
        color:             Qt.rgba(0, 0, 0, 0.85)
        anchors.topMargin: 4
        anchors.leftMargin: 2
    }
    // Main text
    Text {
        id: numText
        anchors.centerIn: parent
        text: numberRoot.shownNumber
        font.family:       DisplayState.numberFont
        font.pixelSize:    Math.max(DisplayState.numberFontSize || (DisplayState.fontSize * numberRoot.numScale * layoutMult), 12)
        font.weight:       Font.Black
        font.letterSpacing: -3
        renderType:        Text.NativeRendering
        color:             DisplayState.numberColor
        style:             Text.Raised
        styleColor:        Qt.rgba(0, 0, 0, 0.9)
    }
}
