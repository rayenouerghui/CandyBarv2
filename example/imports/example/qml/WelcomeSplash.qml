import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"

// ── WelcomeSplash ─────────────────────────────────────────────────────────
// Product branding shown once at boot. NOT the business's branding.
// Crossfades into DisplayView after splashDuration ms.

Item {
    id: root

    signal splashComplete

    property int splashDuration: 2200   // ms before crossfade begins

    // Dark background (same as display so crossfade is invisible seam)
    Rectangle {
        anchors.fill: parent
        color: "#0b0d10"
    }

    // Noise texture
    Image {
        anchors.fill: parent
        source: "qrc:/example/res/image/noise_texture.png"
        fillMode: Image.Tile
        opacity: 0.035
        smooth: false
    }

    // Soft top glow
    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: parent.width * 0.7
        height: parent.height * 0.5
        radius: height / 2
        color: "transparent"
        layer.enabled: true
        // Approximating radial gradient with a rectangle + blur would require
        // QtGraphicalEffects; instead use a simple semi-transparent white rect
        // at very low opacity — cheap and works on ARM.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width; height: parent.height
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.03)
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        // Product wordmark
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "CandyBar"
            font.family: DisplayState.uiFont
            font.pixelSize: Math.max(root.height * 0.06, 32)
            font.weight: Font.Light
            font.letterSpacing: 8
            color: "#FFFFFF"
            opacity: 0
            NumberAnimation on opacity {
                running: true
                from: 0; to: 1
                duration: 600
                easing.type: Easing.OutCubic
                delay: 200
            }
        }

        // Tagline
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Queue Display System"
            font.family: DisplayState.uiFont
            font.pixelSize: Math.max(root.height * 0.022, 14)
            font.weight: Font.Light
            color: "#FFFFFF"
            opacity: 0
            NumberAnimation on opacity {
                running: true
                from: 0; to: 0.40
                duration: 600
                easing.type: Easing.OutCubic
                delay: 400
            }
        }

        // Accent underline — touches accent color once, as brand cue
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 0
            height: 2
            radius: 1
            color: DisplayState.accentColor
            Behavior on color { ColorAnimation { duration: 400 } }
            NumberAnimation on width {
                running: true
                from: 0; to: 48
                duration: 500
                easing.type: Easing.OutCubic
                delay: 600
            }
        }
    }

    // Auto-advance timer
    Timer {
        interval: root.splashDuration
        running: true
        repeat: false
        onTriggered: root.splashComplete()
    }
}
