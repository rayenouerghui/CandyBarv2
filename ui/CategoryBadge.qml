import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"

Item {
    id: badgeRoot
    property real numPx: 96
    property real catScale: 0.34
    property color accentColor: DisplayState.accentColor

    // Fixed clearance from the left accent bar to the dot/text, so they
    // never visually collide regardless of implicit-size rounding.
    readonly property int _leftPad:  26
    readonly property int _rightPad: 22

    visible: DisplayState.categoryVisible
    opacity: DisplayState.categoryVisible ? 1 : 0
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth:  DisplayState.categoryVisible ? catRow.implicitWidth + _leftPad + _rightPad : 0
    Layout.preferredHeight: DisplayState.categoryVisible ? catRow.implicitHeight + 22 : 0

    Rectangle {
        id: tagBg
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.34)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 6
            color: badgeRoot.accentColor
            Behavior on color { ColorAnimation { duration: 600 } }
        }
    }

    RowLayout {
        id: catRow
        anchors {
            left: parent.left
            leftMargin: badgeRoot._leftPad
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 10
            height: 10
            radius: 5
            color: badgeRoot.accentColor
            Behavior on color { ColorAnimation { duration: 600 } }
        }

        Item {
            Layout.maximumWidth: badgeRoot.parent ? badgeRoot.parent.width * 0.9 : 800
            Layout.preferredWidth: catText.implicitWidth
            Layout.preferredHeight: catText.implicitHeight
            Text {
                id: catShadow1
                anchors.centerIn: parent
                text: DisplayState.categoryDisplayName.toUpperCase()
                font.family: DisplayState.categoryFont || DisplayState.numberFont
                font.pixelSize: Math.max(DisplayState.categoryFontSize || (numPx * catScale), 20)
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Qt.rgba(0,0,0,0.7)
                anchors.topMargin: 2
                anchors.leftMargin: 1
            }
            Text {
                id: catText
                anchors.centerIn: parent
                text: DisplayState.categoryDisplayName.toUpperCase()
                font.family: DisplayState.categoryFont || DisplayState.numberFont
                font.pixelSize: Math.max(DisplayState.categoryFontSize || (numPx * catScale), 20)
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: DisplayState.categoryColor
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.8)
            }
        }
    }
}
