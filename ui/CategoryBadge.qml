import QtQuick 6.2
import QtQuick.Layouts 6.2
import "global"

// Accent-tinted glass chip for a black background. Gradient runs from
// a tinted-accent top to a neutral-dark bottom, so it always stays
// legible against any background image/video while visually "belonging"
// to the same palette as the serving number (both driven by accentColor).
Item {
    id: badgeRoot

    property real numPx: 96
    property real catScale: 0.34

    readonly property int horizontalPadding: 26
    readonly property int verticalPadding: 12
    readonly property real pillRadius: height / 2

    visible: DisplayState.categoryVisible
    opacity: DisplayState.categoryVisible ? 1.0 : 0.0
    scale: DisplayState.categoryVisible ? 1.0 : 0.94

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredWidth: catLabel.implicitWidth + horizontalPadding * 2
    Layout.preferredHeight: catLabel.implicitHeight + verticalPadding * 2

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 260; easing.type: Easing.OutBack }
    }

    // Soft shadow, fully behind the chip — never touches the text.
    // Positioned entirely via anchors (fill + margins), no explicit y.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: badgeRoot.pillRadius + 3
        color: Qt.rgba(0, 0, 0, 0.35)
        z: -1
    }

    // Accent-tinted glass surface — gradient from tinted-accent top to
    // neutral-dark bottom. Guarantees contrast against any background
    // (the dark-leaning bottom half) while tying the chip's color to
    // the number's accent color (the tinted top half).
    Rectangle {
        id: badgeSurface
        anchors.fill: parent
        radius: badgeRoot.pillRadius

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(
                    DisplayState.accentColor.r * 0.35,
                    DisplayState.accentColor.g * 0.35,
                    DisplayState.accentColor.b * 0.35,
                    0.55
                )
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0, 0, 0, 0.55)
            }
        }

        border.width: 1.5
        border.color: Qt.rgba(
            DisplayState.accentColor.r,
            DisplayState.accentColor.g,
            DisplayState.accentColor.b,
            0.45
        )
    }

    // Text sits on its own, above everything, with its own contrast shadow
    // so it stays legible regardless of what's behind it.
    Text {
        id: catLabel
        anchors.centerIn: parent
        z: 10

        text: DisplayState.categoryDisplayName.toUpperCase()

        font.family: DisplayState.categoryFont || DisplayState.numberFont
        font.pixelSize: Math.max(DisplayState.categoryFontSize || (badgeRoot.numPx * badgeRoot.catScale), 20)
        font.weight: Font.Bold
        font.letterSpacing: 1.2

        color: "white"
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.6)

        renderType: Text.NativeRendering
    }
}