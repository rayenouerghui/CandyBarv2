import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"

Item {
    id: labelRoot
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: labelText.implicitWidth
    Layout.preferredHeight: labelText.implicitHeight

    Text {
        id: shadowLabel1
        anchors.centerIn: parent
        text: DisplayState.tr("now_serving")
        font.family: DisplayState.nowServingFont || DisplayState.numberFont
        font.pixelSize: Math.max(DisplayState.nowServingFontSize || (labelRoot.parent ? Math.max(labelRoot.parent.height * 0.021, 11) : 12), 10)
        font.letterSpacing: 5
        font.weight: Font.Bold
        color: Qt.rgba(0, 0, 0, 0.75)
        anchors.topMargin: 4
        anchors.leftMargin: 2
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: DisplayState.tr("now_serving")
        font.family: DisplayState.nowServingFont || DisplayState.numberFont
        font.pixelSize: Math.max(DisplayState.nowServingFontSize || (labelRoot.parent ? Math.max(labelRoot.parent.height * 0.021, 11) : 12), 10)
        font.letterSpacing: 5
        font.weight: Font.Bold
        color: DisplayState.nowServingColor
        opacity: 0.98
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.85)
    }
}
