import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"

// ── WelcomeSplash ─────────────────────────────────────────────────────────
// Product branding shown once at boot. NOT the business's branding.
// Crossfades into DisplayView after splashDuration ms.
//
// Enter motion inspired by material-components-qml AppRoot.qml playPageEnter()
// (opacity + vertical settle, OutCubic). Staggered label tiers follow
// QML-UI-Animations LoginStack opacity ladder pattern.

Item {
    id: root

    signal splashComplete

    readonly property int dur_micro: 150
    readonly property int dur_std:   300
    readonly property int dur_full:  600

    property int splashDuration: 2600   // ms before crossfade begins

    // Dark background (same as display so crossfade is invisible seam)
    Rectangle {
        anchors.fill: parent
        color: "#0b0d10"
    }

    Image {
        anchors.fill: parent
        source: "qrc:/example/res/image/noise_texture.png"
        fillMode: Image.Tile
        opacity: 0.035
        smooth: false
        cache: true
    }

    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: parent.width * 0.65
        height: parent.height * 0.45
        radius: height * 0.5
        color: Qt.rgba(1, 1, 1, 0.025)
    }

    Rectangle {
        anchors { bottom: parent.bottom; right: parent.right }
        width: parent.width * 0.45
        height: parent.height * 0.45
        radius: height * 0.5
        color: DisplayState.accentAlpha(0.08)
    }

    // Brand cluster — lifts into place as one unit, then sub-elements stagger
    Item {
        id: brand_cluster
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.max(parent.height * 0.03, 12)
        width: brand_column.implicitWidth
        height: brand_column.implicitHeight
        opacity: 0
        transform: Translate { id: brand_lift; y: 16 }

        Column {
            id: brand_column
            anchors.centerIn: parent
            spacing: 10

            Text {
                id: splash_title
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CandyBar"
                font.family: DisplayState.uiFont
                font.pixelSize: Math.max(root.height * 0.058, 34)
                font.weight: Font.Light
                font.letterSpacing: 6
                color: "#FFFFFF"
                opacity: 0
            }

            Text {
                id: splash_sub
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Queue Display System"
                font.family: DisplayState.uiFont
                font.pixelSize: Math.max(root.height * 0.022, 13)
                font.weight: Font.Light
                font.letterSpacing: 1
                color: "#FFFFFF"
                opacity: 0
            }

            Rectangle {
                id: splash_line
                anchors.horizontalCenter: parent.horizontalCenter
                width: 0
                height: 2
                radius: 1
                color: DisplayState.accentColor
            }
        }
    }

    ParallelAnimation {
        id: brand_enter
        running: true
        NumberAnimation { target: brand_cluster; property: "opacity"; from: 0; to: 1; duration: root.dur_full; easing.type: Easing.OutCubic }
        NumberAnimation { target: brand_lift; property: "y"; from: 16; to: 0; duration: root.dur_full; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: root.dur_micro }
        NumberAnimation { target: splash_title; property: "opacity"; from: 0; to: 1; duration: root.dur_full; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: root.dur_std }
        NumberAnimation { target: splash_sub; property: "opacity"; from: 0; to: 0.42; duration: root.dur_full; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: root.dur_std + root.dur_micro }
        NumberAnimation { target: splash_line; property: "width"; from: 0; to: 52; duration: root.dur_std; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: root.splashDuration
        running: true
        repeat: false
        onTriggered: root.splashComplete()
    }
}
