import QtQuick 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0
import "global"

// ── DisplayView ──────────────────────────────────────────────────────────
// The permanent, always-on display. Hosts Classic, Split, and Centered layouts.
// All three stay in the tree; opacity crossfade switches between them.
//
// Visual design spec:
//   Background: #0b0d10 solid + noise texture (static PNG, ARM-safe) +
//               soft white radial top glow + accent-tinted corner glow
//   Typography: DM Mono Medium for the number (tabular figures), system font elsewhere
//   Accent:     touches only logo bg + number underline (2 elements max)
//   Motion:     number change = lift+shrink+fade out (150ms InCubic),
//               then rise+grow+fade in (300ms OutQuart) — one transform stack,
//               no stacked unrelated animations

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

    // Per-layout number scale — shared treatment, layout-appropriate size
    readonly property real numLayoutClassic:  1.00
    readonly property real numLayoutSplit:    1.08
    readonly property real numLayoutCentered: 1.22

    // Tight tracking binds multi-digit blocks into one readable unit at distance
    readonly property int numLetterSpacing: -3

    // Optical centering — focal content sits slightly above geometric center
    readonly property real numOpticalLift: -Math.max(root.height * 0.03, 12)

    // ── Shared serving-number building blocks (all three layouts) ────────
    component ServingLabel: Text {
        Layout.alignment: Qt.AlignHCenter
        text: "NOW SERVING"
        font.family: DisplayState.uiFont
        font.pixelSize: Math.max(root.height * 0.027, 11)
        font.letterSpacing: 6
        font.weight: Font.Light
        color: "#FFFFFF"
        opacity: 0.42
    }

    component ServingNumber: Item {
        property real layoutMult: 1.0

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth:  numText.implicitWidth
        Layout.preferredHeight: numText.implicitHeight
        opacity: root._numOpacity
        scale: root._numScale
        transformOrigin: Item.Center
        transform: Translate { y: root._numTranslateY }

        Text {
            id: numText
            anchors.centerIn: parent
            text: root._shownNumber
            font.family: DisplayState.numberFont
            font.pixelSize: DisplayState.fontSize * root.numScale * layoutMult
            font.weight: Font.Medium
            font.letterSpacing: root.numLetterSpacing
            renderType: Text.NativeRendering
            color: "#FFFFFF"
        }
    }

    component ServingUnderline: Item {
        property real layoutMult: 1.0

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth:  bar.width
        Layout.preferredHeight: bar.height
        opacity: root._numOpacity
        scale: root._numScale
        transformOrigin: Item.Center
        transform: Translate { y: root._numTranslateY * 0.35 }

        Rectangle {
            id: bar
            anchors.centerIn: parent
            width: Math.max(48, DisplayState.fontSize * root.numScale * layoutMult * 0.44)
            height: 3
            radius: 2
            color: DisplayState.accentColor
            Behavior on color { ColorAnimation { duration: root.dur_full } }
        }
    }

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
        color:  DisplayState.accentAlpha(0.08)
        Behavior on color { ColorAnimation { duration: dur_full } }
    }

    // ── Number change animation controller ───────────────────────────────
    // Outgoing: lift slightly + shrink + fade (150ms InCubic — calm exit)
    // Incoming: rise from below + grow + fade in (300ms OutQuart — decisive arrival)
    // Transform stack: opacity + scale + translateY only (GPU-cheap)
    property string _shownNumber: DisplayState.currentNumber
    property real   _numOpacity:  1.0
    property real   _numScale:    1.0
    property real   _numTranslateY: 0

    readonly property real _numOutScale:    0.86
    readonly property real _numInFromScale: 0.90
    readonly property real _numOutLift:     Math.max(root.height * 0.022, 8)
    readonly property real _numInDrop:      Math.max(root.height * 0.028, 10)

    function _resetNumberAnimState() {
        _numOpacity    = 1.0
        _numScale      = 1.0
        _numTranslateY = 0
    }

    onVisibleChanged: {
        if (visible) {
            _shownNumber = DisplayState.currentNumber
            _resetNumberAnimState()
        }
    }

    Connections {
        target: DisplayState
        function onCurrentNumberChanged() {
            if (_shownNumber === DisplayState.currentNumber)
                return
            num_change_anim.stop()
            num_change_anim.start()
        }
    }

    SequentialAnimation {
        id: num_change_anim
        alwaysRunToEnd: false

        // Phase 1: outgoing number recedes upward
        ParallelAnimation {
            NumberAnimation { target: root; property: "_numOpacity";    to: 0;                 duration: root.dur_micro; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_numScale";      to: root._numOutScale;  duration: root.dur_micro; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_numTranslateY"; to: -root._numOutLift;  duration: root.dur_micro; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                root._shownNumber   = DisplayState.currentNumber
                root._numTranslateY = root._numInDrop
                root._numScale      = root._numInFromScale
                root._numOpacity    = 0
            }
        }
        // Phase 2: incoming number settles into place
        ParallelAnimation {
            NumberAnimation { target: root; property: "_numOpacity";    to: 1;   duration: root.dur_std; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "_numScale";      to: 1.0; duration: root.dur_std; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "_numTranslateY"; to: 0;   duration: root.dur_std; easing.type: Easing.OutQuart }
        }
    }

    // ── Layout switcher ──────────────────────────────────────────────────
    // All three layouts always exist; crossfade between them on layoutType change.
    property real _classicOpacity:  DisplayState.layoutType === "Classic"  ? 1 : 0
    property real _splitOpacity:    DisplayState.layoutType === "Split"    ? 1 : 0
    property real _centeredOpacity: DisplayState.layoutType === "Centered" ? 1 : 0

    Behavior on _classicOpacity  { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }
    Behavior on _splitOpacity    { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }
    Behavior on _centeredOpacity { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }

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
                        color: DisplayState.accentAlpha(0.20)
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
                    anchors.verticalCenterOffset: root.numOpticalLift
                    spacing: 0

                    ServingLabel {
                        Layout.bottomMargin: Math.max(root.height * 0.018, 10)
                    }

                    ServingNumber {
                        layoutMult: root.numLayoutClassic
                        Layout.bottomMargin: Math.max(root.height * 0.014, 8)
                    }

                    ServingUnderline {
                        layoutMult: root.numLayoutClassic
                        Layout.bottomMargin: Math.max(root.height * 0.018, 10)
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
                    anchors.verticalCenterOffset: root.numOpticalLift
                    spacing: 0

                    // Logo — accent bg
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Math.max(root.height * 0.022, 12)
                        width: 56; height: 56; radius: root.radius_chip
                        color: DisplayState.accentAlpha(0.18)
                        Behavior on color { ColorAnimation { duration: root.dur_full } }
                        Image {
                            anchors { fill: parent; margins: 4 }
                            source: DisplayState.logoSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(112, 112)
                        }
                    }

                    ServingLabel {
                        Layout.bottomMargin: Math.max(root.height * 0.016, 8)
                    }

                    ServingNumber {
                        layoutMult: root.numLayoutSplit
                        Layout.bottomMargin: Math.max(root.height * 0.012, 6)
                    }

                    ServingUnderline {
                        layoutMult: root.numLayoutSplit
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

    // ── CENTERED LAYOUT ───────────────────────────────────────────────────
    // Minimal, symmetrical. Logo top-center, number center-screen (large),
    // facility name below, accent underline. No header bar, no footer ticker.
    // Designed for very large rooms where the number alone needs to fill the frame.
    Item {
        id: centered_layout
        anchors.fill: parent
        opacity: root._centeredOpacity
        visible: opacity > 0

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.numOpticalLift
            spacing: 0

            // Logo — accent-tinted badge, larger than other layouts
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Math.max(root.height * 0.04, 16)
                width: 72; height: 72; radius: root.radius_card
                color: DisplayState.accentAlpha(0.18)
                Behavior on color { ColorAnimation { duration: root.dur_full } }
                Image {
                    anchors { fill: parent; margins: 6 }
                    source: DisplayState.logoSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(144, 144)
                }
            }

            ServingLabel {
                Layout.bottomMargin: Math.max(root.height * 0.018, 10)
            }

            ServingNumber {
                layoutMult: root.numLayoutCentered
                Layout.bottomMargin: Math.max(root.height * 0.016, 8)
            }

            ServingUnderline {
                layoutMult: root.numLayoutCentered
                Layout.bottomMargin: Math.max(root.height * 0.022, 12)
            }

            // Facility name
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: DisplayState.facilityName
                font.family: DisplayState.uiFont
                font.pixelSize: Math.max(root.height * 0.026, 12)
                font.weight: Font.Light
                color: "#FFFFFF"
                opacity: 0.42
                elide: Text.ElideRight
            }
        }
    }
}
