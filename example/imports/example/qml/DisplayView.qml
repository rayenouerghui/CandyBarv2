import QtQuick 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0
import "global"

// ── DisplayView ──────────────────────────────────────────────────────────
// The permanent, always-on display. Hosts Classic and Split layouts.
// Both are kept in the component tree but toggled via opacity/visible so
// layout switching can be animated (crossfade) without reload.
//
// Visual design spec:
//   Background: #0b0d10 solid + noise texture (static PNG, ARM-safe) +
//               soft white radial top glow + accent-tinted corner glow
//   Typography: DM Mono for the number (tabular figures), system font elsewhere
//   Accent:     touches only logo bg + number underline (2 elements max)
//   Motion:     number change = outgoing scale↓+fade, incoming scale↑+fade
//                               250-350ms OutCubic, no bounce/overshoot

Item {
    id: root
    anchors.fill: parent

    // ── Design constants ─────────────────────────────────────────────────
    readonly property int dur_micro:   150   // hover / press feedback
    readonly property int dur_std:     300   // state transitions
    readonly property int dur_full:    600   // full state changes

    readonly property int radius_outer: 18
    readonly property int radius_card:  12
    readonly property int radius_chip:  10

    // Font scale: number pixel-size relative to display height
    readonly property real numScale: Math.max(root.height / 480.0, 0.8)

    // ── Background layers (shared by both layouts) ───────────────────────
    Rectangle {
        id: bg_base
        anchors.fill: parent
        color: "#0b0d10"
    }

    // Static noise texture — pre-rendered PNG, tiled, ~3.5% opacity
    // NO shader; compositing a static texture is trivially cheap on ARM
    Image {
        id: noise_layer
        anchors.fill: parent
        source: "qrc:/example/res/image/noise_texture.png"
        fillMode: Image.Tile
        opacity: 0.035
        smooth: false   // nearest-neighbour: no filtering cost
        cache: true
    }

    // Soft white radial top glow — lifts the top of the frame
    // Implemented as a low-opacity gradient rectangle; no QtGraphicalEffects
    Rectangle {
        id: glow_top
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width:  parent.width * 0.65
        height: parent.height * 0.45
        radius: height * 0.5
        color: Qt.rgba(1, 1, 1, 0.025)
        // Feathered by the high radius; no blur shader needed
    }

    // Accent-tinted corner glow — bottom-right, ties accent to the space
    Rectangle {
        id: glow_accent
        anchors { bottom: parent.bottom; right: parent.right }
        width:  parent.width  * 0.45
        height: parent.height * 0.45
        radius: height * 0.5
        color:  Qt.rgba(
                    DisplayState.accentColor.r,
                    DisplayState.accentColor.g,
                    DisplayState.accentColor.b,
                    0.08)
        Behavior on color { ColorAnimation { duration: dur_full } }
    }

    // ── Number change animation controller ───────────────────────────────
    // Outgoing: scale to 0.88 + fade to 0 (150ms InCubic)
    // Incoming: scale from 0.92 to 1.0 + fade in (300ms OutCubic)
    // Driven by DisplayState.currentNumber change
    property string _shownNumber: DisplayState.currentNumber
    property real   _numOpacity:  1.0
    property real   _numScale:    1.0

    onVisibleChanged: { if (visible) _shownNumber = DisplayState.currentNumber }

    Connections {
        target: DisplayState
        function onCurrentNumberChanged() {
            num_out_anim.start()
        }
    }

    SequentialAnimation {
        id: num_out_anim
        // Phase 1: outgoing number fades/shrinks
        ParallelAnimation {
            NumberAnimation { target: root; property: "_numOpacity"; to: 0;    duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_numScale";   to: 0.88; duration: 150; easing.type: Easing.InCubic }
        }
        // Swap the displayed number
        ScriptAction { script: { root._shownNumber = DisplayState.currentNumber } }
        // Phase 2: incoming number scales up / fades in
        ParallelAnimation {
            NumberAnimation { target: root; property: "_numOpacity"; to: 1;   duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "_numScale";   to: 1.0; duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // ── Layout switcher ──────────────────────────────────────────────────
    // Both layouts always exist; crossfade between them on layoutType change.
    property real _classicOpacity: DisplayState.layoutType === "Classic" ? 1 : 0
    property real _splitOpacity:   DisplayState.layoutType === "Split"   ? 1 : 0

    Behavior on _classicOpacity { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }
    Behavior on _splitOpacity   { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }

    // ── CLASSIC LAYOUT ───────────────────────────────────────────────────
    Item {
        id: classic_layout
        anchors.fill: parent
        opacity: root._classicOpacity
        visible: opacity > 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header bar — translucent surface, not a solid color
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(root.height * 0.13, 56)
                color: Qt.rgba(1, 1, 1, 0.05)

                RowLayout {
                    anchors { fill: parent; leftMargin: 28; rightMargin: 28 }
                    spacing: 16

                    // Logo container — accent color here (1 of 2 accent touches)
                    Rectangle {
                        width: 44; height: 44; radius: root.radius_chip
                        color: Qt.rgba(
                                   DisplayState.accentColor.r,
                                   DisplayState.accentColor.g,
                                   DisplayState.accentColor.b,
                                   0.20)
                        Behavior on color { ColorAnimation { duration: root.dur_full } }
                        Image {
                            anchors { fill: parent; margins: 4 }
                            source: DisplayState.logoSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(88, 88)
                        }
                    }

                    Text {
                        text: DisplayState.facilityName
                        font.family: DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.030, 13)
                        font.weight: Font.Light
                        color: "#FFFFFF"
                        opacity: 0.92
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        id: clock_text_classic
                        font.family: DisplayState.numberFont
                        font.pixelSize: Math.max(root.height * 0.026, 12)
                        color: "#FFFFFF"
                        opacity: 0.42
                    }
                    Timer {
                        interval: 1000; repeat: true; running: classic_layout.visible
                        onTriggered: clock_text_classic.text = Qt.formatTime(new Date(), "HH:mm")
                    }
                }
            }

            // Central — "NOW SERVING" + number
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NOW SERVING"
                        font.family: DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.028, 11)
                        font.letterSpacing: 7
                        font.weight: Font.Light
                        color: "#FFFFFF"
                        opacity: 0.42
                    }

                    // The number — DM Mono, animated via root._shownNumber
                    Text {
                        id: number_classic
                        Layout.alignment: Qt.AlignHCenter
                        text: root._shownNumber
                        font.family: DisplayState.numberFont
                        font.pixelSize: DisplayState.fontSize * root.numScale
                        font.weight: Font.Medium
                        color: "#FFFFFF"
                        opacity: root._numOpacity
                        scale:  root._numScale
                        // No Behavior here — driven by the SequentialAnimation above
                    }

                    // Accent underline — 2nd of 2 accent touches
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 44; height: 3; radius: 2
                        color: DisplayState.accentColor
                        Behavior on color { ColorAnimation { duration: root.dur_full } }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Please proceed to your counter"
                        font.family: DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.024, 10)
                        color: "#FFFFFF"
                        opacity: 0.30
                    }
                }
            }

            // Footer banner ticker
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(root.height * 0.10, 40)
                color: Qt.rgba(1, 1, 1, 0.04)
                clip: true

                Row {
                    id: ticker_row
                    height: parent.height
                    spacing: 96
                    // Three copies so seamless loop never shows a gap
                    Repeater {
                        model: 3
                        Text {
                            height: ticker_row.height
                            verticalAlignment: Text.AlignVCenter
                            text: "  ·  " + DisplayState.bannerText
                            font.family: DisplayState.uiFont
                            font.pixelSize: Math.max(root.height * 0.028, 12)
                            color: "#FFFFFF"
                            opacity: 0.42
                        }
                    }
                    NumberAnimation on x {
                        from: 0
                        to: -(ticker_row.width / 3)
                        duration: 14000
                        loops: Animation.Infinite
                        running: classic_layout.visible
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    // ── SPLIT LAYOUT ─────────────────────────────────────────────────────
    Item {
        id: split_layout
        anchors.fill: parent
        opacity: root._splitOpacity
        visible: opacity > 0

        Row {
            anchors.fill: parent

            // Left panel — 55% — current number
            Item {
                width: parent.width * 0.55
                height: parent.height

                // Slightly elevated surface
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(1, 1, 1, 0.04)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    // Logo — accent bg
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 56; height: 56; radius: root.radius_chip
                        color: Qt.rgba(
                                   DisplayState.accentColor.r,
                                   DisplayState.accentColor.g,
                                   DisplayState.accentColor.b,
                                   0.18)
                        Behavior on color { ColorAnimation { duration: root.dur_full } }
                        Image {
                            anchors { fill: parent; margins: 4 }
                            source: DisplayState.logoSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(112, 112)
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NOW SERVING"
                        font.family: DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.026, 11)
                        font.letterSpacing: 6
                        font.weight: Font.Light
                        color: "#FFFFFF"
                        opacity: 0.42
                    }

                    Text {
                        id: number_split
                        Layout.alignment: Qt.AlignHCenter
                        text: root._shownNumber
                        font.family: DisplayState.numberFont
                        font.pixelSize: DisplayState.fontSize * root.numScale * 1.05
                        font.weight: Font.Medium
                        color: "#FFFFFF"
                        opacity: root._numOpacity
                        scale:  root._numScale
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 36; height: 3; radius: 2
                        color: DisplayState.accentColor
                        Behavior on color { ColorAnimation { duration: root.dur_full } }
                    }
                }
            }

            // Right panel — 45% — next up queue
            Item {
                width: parent.width * 0.45
                height: parent.height

                ColumnLayout {
                    anchors { fill: parent; margins: 28; topMargin: 40 }
                    spacing: 0

                    Text {
                        text: "NEXT UP"
                        font.family: DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.024, 10)
                        font.letterSpacing: 5
                        font.weight: Font.Light
                        color: "#FFFFFF"
                        opacity: 0.30
                        Layout.bottomMargin: 20
                    }

                    // Dynamic next-up list — from DisplayState.nextUp
                    // Falls back to auto-generated numbers if nextUp is empty
                    Repeater {
                        model: {
                            var nu = DisplayState.nextUp
                            if (nu && nu.length > 0) return nu.slice(0, 4)
                            // Fallback: auto-generate current+1…+4
                            var base = parseInt(DisplayState.currentNumber) || 0
                            var arr = []
                            for (var i = 1; i <= 4; i++) {
                                arr.push(String(base + i).padStart(3, '0'))
                            }
                            return arr
                        }

                        delegate: Item {
                            Layout.fillWidth: true
                            height: 54

                            Rectangle {
                                anchors { fill: parent; topMargin: 3; bottomMargin: 3 }
                                radius: root.radius_chip
                                color: Qt.rgba(1, 1, 1, 0.04)
                            }

                            Text {
                                anchors {
                                    left: parent.left; leftMargin: 18
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData
                                font.family: DisplayState.numberFont
                                font.pixelSize: Math.max(root.height * 0.042, 18)
                                font.weight: Font.Normal
                                color: "#FFFFFF"
                                // Decreasing opacity for visual hierarchy
                                opacity: 1.0 - index * 0.20
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Banner at bottom of right panel
                    Rectangle {
                        Layout.fillWidth: true
                        height: Math.max(root.height * 0.09, 40)
                        radius: root.radius_card
                        color: Qt.rgba(1, 1, 1, 0.05)

                        Text {
                            anchors {
                                left: parent.left; leftMargin: 14
                                right: parent.right; rightMargin: 14
                                verticalCenter: parent.verticalCenter
                            }
                            text: DisplayState.bannerText
                            font.family: DisplayState.uiFont
                            font.pixelSize: Math.max(root.height * 0.022, 10)
                            color: "#FFFFFF"
                            opacity: 0.30
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }
                    }
                }
            }
        }
    }
}
