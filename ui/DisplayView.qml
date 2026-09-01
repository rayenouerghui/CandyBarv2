import QtQuick 2.15
import QtQuick.Layouts 1.15
import "global"
import "."

// ── DisplayView ──────────────────────────────────────────────────────────
// The permanent, always-on display. Hosts Split and Centered layouts.
// Both stay in the tree; opacity crossfade switches between them.
//
// Hierarchy (3-meter read test, highest to lowest):
//   1. NUMBER        — commands the screen, heaviest weight, largest size
//   2. CATEGORY      — now a high-contrast BADGE, bold, unmissable, tier 2
//   3. "NOW SERVING" — whisper label, small, subordinate
//   4. Everything else (facility, clock, banner, next-up) — clearly tertiary
//
// ── WHY THE CATEGORY WAS INVISIBLE ───────────────────────────────────────
// The old CategoryTitle rendered as bare text in `accent_gold` directly on
// top of a photographic background with no guaranteed contrast surface.
// On warm/bright backgrounds the gold text blended straight into the photo.
// The number survives this because it's huge + white + heavily weighted;
// the (much smaller) category never could.
//
// FIX: the category is now a self-contained "badge" — a translucent,
// bordered pill that carries its own contrast independent of whatever
// photo is behind it — combined with a soft glass card behind the whole
// number+category stack so BOTH stay legible on any background image.
//
// Motion: number change = lift+shrink+fade out (150ms InCubic),
//         then rise+grow+fade in (300ms OutQuart) — GPU-only transforms

Item {
    id: root
    anchors.fill: parent

    // ── Timing constants ─────────────────────────────────────────────────
    readonly property int dur_micro: 0   // number exit (disabled for performance)
    readonly property int dur_std:   0   // number entrance / state transitions (disabled)
    readonly property int dur_full:  0   // layout crossfade / color transitions (disabled)

    // ── Radius tokens ────────────────────────────────────────────────────
    readonly property int radius_outer: 20
    readonly property int radius_card:  14
    readonly property int radius_chip:  12

    // ── Typography scale ─────────────────────────────────────────────────
    // numScale: multiplier so the number fills the screen proportionally
    readonly property real numScale: Math.max(root.height / 480.0, 0.8)

    // ── Animation properties (disabled for performance) ─────────────────
    property real _numOpacity: 1.0
    property real _numScale: 1.0
    property real _numTranslateY: 0

    // Per-layout number multipliers — Centered gets the most room
    readonly property real numLayoutSplit:    1.10
    readonly property real numLayoutCentered: 1.30
    readonly property real numLayoutTop: 1.45

    // DESIGN CHANGE: category is now sized as a larger fraction of the number
    // (0.32–0.38 instead of the old 0.24–0.28) so it reads clearly as its
    // own tier rather than a caption. Because it now lives inside a badge
    // with guaranteed contrast, it can afford to be bigger without
    // competing visually with the number.
    readonly property real catScaleSplit:    0.32
    readonly property real catScaleCentered: 0.38
    readonly property real catScaleTop:  0.26 

    // Tight tracking — binds digits into one readable unit at distance
    readonly property int numLetterSpacing: -3

    // Optical lift — focal pair sits slightly above geometric center
    readonly property real numOpticalLift: -Math.max(root.height * 0.04, 16)

    // ── Color palette ────────────────────────────────────────────────────
    readonly property color text_primary:   DisplayState.accentColor
    readonly property color text_secondary: Qt.lighter(DisplayState.accentColor, 1.55)
    readonly property color text_tertiary:  Qt.lighter(DisplayState.accentColor, 1.28)
    property color accent_gold:     DisplayState.accentColor
    property color accent_gold_dim: Qt.rgba(DisplayState.accentColor.r,
                                            DisplayState.accentColor.g,
                                            DisplayState.accentColor.b, 0.15)

    // Glass card behind the whole number+category stack — a soft, neutral
    // dark scrim that guarantees a stable contrast surface no matter what
    // photo is loaded as the background.
    readonly property color glass_fill:   Qt.rgba(0, 0, 0, 0.32)
    readonly property color glass_border: Qt.rgba(1, 1, 1, 0.14)
    readonly property color glass_shadow: Qt.rgba(0, 0, 0, 0.28)
    readonly property color glass_highlight: Qt.rgba(1, 1, 1, 0.08)



    BackgroundDisplay {
        anchors.fill: parent
    }

    // Dark scrim — enough for text contrast, not so much it kills the image
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.06)   // was 0.22 — barely tints the photo now
    }

    // ── Number change animation ──────────────────────────────────────────
    // Disabled for performance on Raspberry Pi
    property string _shownNumber:   DisplayState.currentNumber

    property real _split1Opacity:    0
    property real _split2Opacity:    0
    property real _centeredOpacity: 1

    function _applyLayout(lt) {
         var known = (lt === "Split1" || lt === "Split2" || lt === "Centered")
         var safeLt = known ? lt : "Centered"   // never render a blank screen
         if (!known) console.warn("DisplayView: unknown layoutType, falling back to Centered:", lt)

         _split1Opacity    = (safeLt === "Split1")    ? 1 : 0
         _split2Opacity    = (safeLt === "Split2")    ? 1 : 0
         _centeredOpacity = (safeLt === "Centered") ? 1 : 0
         if (safeLt === "Split1"    && split_ticker_anim)    split_ticker_anim.restart()
         if (safeLt === "Split2"    && split2_ticker_anim)   split2_ticker_anim.restart()
         if (safeLt === "Centered" && centered_ticker_anim) centered_ticker_anim.restart()
    }

    Connections {
        target: DisplayState
        function onLayoutTypeChanged() { root._applyLayout(DisplayState.layoutType) }
    }

    Component.onCompleted: _applyLayout(DisplayState.layoutType)

    // ── Boot geometry fix (Raspberry Pi / eglfs) ────────────────────────────
    // On embedded platforms the window's first reported geometry can be stale
    // until an actual resize/expose event fires. In windowed dev mode, Escape
    // happens to trigger that event — but kiosk fullscreen on the Pi never
    // gets one. This timer re-runs layout + restarts the ticker animations
    // once real geometry has settled, without needing any user interaction.
    Timer {
        id: boot_relayout_kick
        interval: 500
        running: true
        repeat: false
        onTriggered: root._applyLayout(DisplayState.layoutType)
    }


    // ════════════════════════════════════════════════════════════════════
    // SPLIT 1 LAYOUT
    // Left 55%:  glass card ▸ logo → NowServingLabel → CategoryBadge → Number → Underline
    // Right 45%: "NEXT UP" queue (clearly subordinate)
    // ════════════════════════════════════════════════════════════════════
    Item {
        id: split1_layout
        anchors.fill: parent
        opacity: root._split1Opacity
        visible: opacity > 0
        onVisibleChanged: {
        if (visible && split_ticker_anim) split_ticker_anim.restart()
        }

        // Logo — positioned absolutely based on logoPosition (full width)
        LogoComponent {
            id: splitLogo
            baseSize: DisplayState.logoSize
            layoutMult: 1.0
        }

        Row {
            anchors.fill: parent

            // ── Left panel — primary content ──────────────────────────────
            Item {
                width:  parent.width * 0.55
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.10)
                }

                // Cadre frame wrapping the main content
                CadreComponent {
                    id: split_cadre
                    anchors.centerIn: parent
                    width: split_layout_stack.implicitWidth + (DisplayState.cadreEnabled ? DisplayState.cadrePadding * 2 : 0)
                    height: split_layout_stack.implicitHeight + (DisplayState.cadreEnabled ? DisplayState.cadrePadding * 2 : 0)
                    cadreType: DisplayState.cadreType
                    cadreOpacity: DisplayState.cadreOpacity
                    cadreBlur: DisplayState.cadreBlur
                    cornerRadius: DisplayState.cadrecornerRadius
                    borderWidth: DisplayState.cadreBorderWidth
                    padding: DisplayState.cadrePadding

                    ColumnLayout {
                        id: split_layout_stack
                        anchors.centerIn: parent
                        spacing: Math.max(root.height * 0.016, 10)

                        CategoryBadge {
                            numPx: DisplayState.fontSize * root.numScale * root.numLayoutSplit
                            catScale: root.catScaleSplit
                            Layout.alignment: Qt.AlignHCenter
                            visible: DisplayState.categoryVisible
                        }

                        NowServingLabel {
                            Layout.alignment: Qt.AlignHCenter
                            visible: DisplayState.nowServingVisible
                        }

                        ServingNumber {
                            id: split_number
                            layoutMult: root.numLayoutSplit
                            numScale: root.numScale
                            shownNumber: root._shownNumber
                            rootOpacity: root._numOpacity
                            rootScale: root._numScale
                            rootTranslateY: root._numTranslateY
                            Layout.alignment: Qt.AlignHCenter
                        }

                        AccentUnderline {
                            layoutMult: root.numLayoutSplit
                            numScale: root.numScale
                            rootOpacity: root._numOpacity
                            rootScale: root._numScale
                            rootTranslateY: root._numTranslateY
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: DisplayState.facilityName
                            font.family: DisplayState.facilityFont || DisplayState.numberFont
                            font.pixelSize: Math.max(DisplayState.facilityFontSize || Math.max(root.height * 0.022, 10), 10)
                            font.weight: Font.Light
                            color: DisplayState.facilityColor
                            opacity: DisplayState.facilityVisible ? 1.0 : 0.0
                            visible: DisplayState.facilityVisible
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.5)
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // ── Right panel — next-up queue (subordinate) ─────────────────
            Item {
                width:  parent.width * 0.45
                height: parent.height

                ColumnLayout {
                    anchors { fill: parent; margins: 28; topMargin: 44 }
                    spacing: 0

                    // "NEXT UP" — stays pinned near the top, centered
                    Text {
                        text:           "NEXT UP"
                        font.family:    DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.048, 24)
                        font.letterSpacing: 5
                        font.weight:    Font.Bold
                        color:          root.text_secondary
                        opacity:        0.85
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.bottomMargin: 8
                        style:          Text.Raised
                        styleColor:     Qt.rgba(0, 0, 0, 0.5)
                    }

                    // Flexible spacer above the list — pushes the number block toward
                    // vertical center along with the spacer below it.
                    Item { Layout.fillHeight: true }

                    // Tightly-packed, centered number list
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Math.max(root.height * 0.012, 6)

                        Repeater {
                            model: {
                                var nu = DisplayState.nextUp
                                if (nu && nu.length > 0) return nu.slice(0, 4)
                                var base = parseInt(DisplayState.currentNumber) || 0
                                var arr = []
                                for (var i = 1; i <= 4; i++)
                                    arr.push(String(base + i).padStart(2, '0'))
                                return arr
                            }

                            delegate: Text {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text:           modelData
                                font.family:    DisplayState.numberFont
                                font.pixelSize: Math.max(root.height * 0.10, 52)
                                font.weight:    Font.Bold
                                color:          DisplayState.numberColor
                                opacity:        0.85 - index * 0.15
                                style:          Text.Raised
                                styleColor:     Qt.rgba(0, 0, 0, 0.55)
                            }
                        }
                    }

                    // Flexible spacer below the list — balances against the one above,
                    // centering the whole NEXT UP block between the header and the banner.
                    Item { Layout.fillHeight: true }

                    // Banner strip — unchanged, keep exactly as it was
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(root.height * 0.07, 32)
                        visible: DisplayState.bannerEnabled
                        radius: root.radius_chip
                        color: Qt.rgba(0, 0, 0, 0.42)
                        clip: true
                        onWidthChanged: if (split_ticker_anim) split_ticker_anim.restart()

                        Row {
                            id: ticker_row_split
                            height: parent.height
                            spacing: 14
                            Repeater {
                                model: 3
                                Text {
                                    height:            ticker_row_split.height
                                    verticalAlignment: Text.AlignVCenter
                                    text:              DisplayState.bannerText + "   ·   "
                                    font.family:       DisplayState.bannerFont || DisplayState.uiFont
                                    font.pixelSize:    Math.max(DisplayState.bannerFontSize || Math.max(root.height * 0.021, 11), 11)
                                    font.weight:       Font.DemiBold
                                    color:             DisplayState.bannerColor
                                    opacity:           0.9
                                    style:             Text.Raised
                                    styleColor:        Qt.rgba(0, 0, 0, 0.6)
                                }
                            }
                            NumberAnimation on x {
                                id: split_ticker_anim
                                from: 0; to: -(ticker_row_split.width / 3)
                                duration: 14000
                                loops: Animation.Infinite
                                running: DisplayState.bannerEnabled; easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // SPLIT 2 LAYOUT
    // Right 55%: glass card ▸ logo → NowServingLabel → CategoryBadge → Number → Underline
    // Left 45%: "NEXT UP" queue (clearly subordinate)
    // ════════════════════════════════════════════════════════════════════
    Item {
        id: split2_layout
        anchors.fill: parent
        opacity: root._split2Opacity
        visible: opacity > 0
        onVisibleChanged: {
            if (visible && split2_ticker_anim) split2_ticker_anim.restart()
        }

        // Logo — positioned absolutely based on logoPosition (full width)
        LogoComponent {
            id: split2Logo
            baseSize: DisplayState.logoSize
            layoutMult: 1.0
        }

        Row {
            anchors.fill: parent

            // ── Left panel — next-up queue (subordinate) ─────────────────
            Item {
                width:  parent.width * 0.45
                height: parent.height

                ColumnLayout {
                    anchors { fill: parent; margins: 28; topMargin: 44 }
                    spacing: 0

                    // "NEXT UP" — stays pinned near the top, centered
                    Text {
                        text:           "NEXT UP"
                        font.family:    DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.048, 24)
                        font.letterSpacing: 5
                        font.weight:    Font.Bold
                        color:          root.text_secondary
                        opacity:        0.85
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.bottomMargin: 8
                        style:          Text.Raised
                        styleColor:     Qt.rgba(0, 0, 0, 0.5)
                    }

                    // Flexible spacer above the list — pushes the number block toward
                    // vertical center along with the spacer below it.
                    Item { Layout.fillHeight: true }

                    // Tightly-packed, centered number list
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Math.max(root.height * 0.012, 6)

                        Repeater {
                            model: {
                                var nu = DisplayState.nextUp
                                if (nu && nu.length > 0) return nu.slice(0, 4)
                                var base = parseInt(DisplayState.currentNumber) || 0
                                var arr = []
                                for (var i = 1; i <= 4; i++)
                                    arr.push(String(base + i).padStart(2, '0'))
                                return arr
                            }

                            delegate: Text {
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                text:           modelData
                                font.family:    DisplayState.numberFont
                                font.pixelSize: Math.max(root.height * 0.10, 52)
                                font.weight:    Font.Bold
                                color:          DisplayState.numberColor
                                opacity:        0.85 - index * 0.15
                                style:          Text.Raised
                                styleColor:     Qt.rgba(0, 0, 0, 0.55)
                            }
                        }
                    }

                    // Flexible spacer below the list — balances against the one above,
                    // centering the whole NEXT UP block between the header and the banner.
                    Item { Layout.fillHeight: true }

                    // Banner strip — unchanged, keep exactly as it was
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(root.height * 0.07, 32)
                        visible: DisplayState.bannerEnabled
                        radius: root.radius_chip
                        color: Qt.rgba(0, 0, 0, 0.42)
                        clip: true
                        onWidthChanged: if (split2_ticker_anim) split2_ticker_anim.restart()

                        Row {
                            id: ticker_row_split2
                            height: parent.height
                            spacing: 14
                            Repeater {
                                model: 3
                                Text {
                                    height:            ticker_row_split2.height
                                    verticalAlignment: Text.AlignVCenter
                                    text:              DisplayState.bannerText + "   ·   "
                                    font.family:       DisplayState.bannerFont || DisplayState.uiFont
                                    font.pixelSize:    Math.max(DisplayState.bannerFontSize || Math.max(root.height * 0.021, 11), 11)
                                    font.weight:       Font.DemiBold
                                    color:             DisplayState.bannerColor
                                    opacity:           0.9
                                    style:             Text.Raised
                                    styleColor:        Qt.rgba(0, 0, 0, 0.6)
                                }
                            }
                            NumberAnimation on x {
                                id: split2_ticker_anim
                                from: 0; to: -(ticker_row_split2.width / 3)
                                duration: 14000
                                loops: Animation.Infinite
                                running: DisplayState.bannerEnabled; easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }

            // ── Right panel — primary content ──────────────────────────────
            Item {
                width:  parent.width * 0.55
                height: parent.height

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.10)
                }

                // Cadre frame wrapping the main content
                CadreComponent {
                    id: split2_cadre
                    anchors.centerIn: parent
                    width: split2_layout_stack.implicitWidth + (DisplayState.cadreEnabled ? DisplayState.cadrePadding * 2 : 0)
                    height: split2_layout_stack.implicitHeight + (DisplayState.cadreEnabled ? DisplayState.cadrePadding * 2 : 0)
                    cadreType: DisplayState.cadreType
                    cadreOpacity: DisplayState.cadreOpacity
                    cadreBlur: DisplayState.cadreBlur
                    cornerRadius: DisplayState.cadrecornerRadius
                    borderWidth: DisplayState.cadreBorderWidth
                    padding: DisplayState.cadrePadding

                    ColumnLayout {
                        id: split2_layout_stack
                        anchors.centerIn: parent
                        spacing: Math.max(root.height * 0.016, 10)

                        CategoryBadge {
                            numPx: DisplayState.fontSize * root.numScale * root.numLayoutSplit
                            catScale: root.catScaleSplit
                            Layout.alignment: Qt.AlignHCenter
                            visible: DisplayState.categoryVisible
                        }

                        NowServingLabel {
                            Layout.alignment: Qt.AlignHCenter
                            visible: DisplayState.nowServingVisible
                        }

                        ServingNumber {
                            id: split2_number
                            layoutMult: root.numLayoutSplit
                            numScale: root.numScale
                            shownNumber: root._shownNumber
                            rootOpacity: root._numOpacity
                            rootScale: root._numScale
                            rootTranslateY: root._numTranslateY
                            Layout.alignment: Qt.AlignHCenter
                        }

                        AccentUnderline {
                            layoutMult: root.numLayoutSplit
                            numScale: root.numScale
                            rootOpacity: root._numOpacity
                            rootScale: root._numScale
                            rootTranslateY: root._numTranslateY
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text:           DisplayState.facilityName
                            font.family:    DisplayState.facilityFont || DisplayState.numberFont
                            font.pixelSize: Math.max(DisplayState.facilityFontSize || Math.max(root.height * 0.022, 10), 10)
                            font.weight:    Font.Light
                            color:          DisplayState.facilityColor
                            opacity:        DisplayState.facilityVisible ? 1.0 : 0.0
                            visible:        DisplayState.facilityVisible
                            style:          Text.Raised
                            styleColor:     Qt.rgba(0, 0, 0, 0.5)
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // CENTERED LAYOUT
    // Pure minimal, on a glass card. Logo top, NowServingLabel,
    // CategoryBadge, Number, Underline, facility name. No header bar,
    // no footer ticker. Designed for large rooms where the number must
    // fill the frame — the category badge scales up right alongside it.
    // ════════════════════════════════════════════════════════════════════
    Item {
        id: centered_layout
        anchors.fill: parent
        opacity: root._centeredOpacity
        visible: opacity > 0
        onVisibleChanged: {
            if (visible && centered_ticker_anim) centered_ticker_anim.restart()
        }

        // Logo — positioned absolutely based on logoPosition
        LogoComponent {
            id: centeredLogo
            baseSize: DisplayState.logoSize
            layoutMult: 1.25
        }

        // Cadre frame wrapping the main content
        CadreComponent {
            id: centered_cadre
            anchors.centerIn: parent
            width: centered_layout_stack.implicitWidth + (DisplayState.cadreEnabled ? DisplayState.cadrePadding * 2 : 0)
            height: centered_layout_stack.implicitHeight + (DisplayState.cadreEnabled ? DisplayState.cadrePadding * 2 : 0)
            cadreType: DisplayState.cadreType
            cadreOpacity: DisplayState.cadreOpacity
            cadreBlur: DisplayState.cadreBlur
            cornerRadius: DisplayState.cadrecornerRadius
            borderWidth: DisplayState.cadreBorderWidth
            padding: DisplayState.cadrePadding

            ColumnLayout {
                id: centered_layout_stack
                anchors.centerIn: parent
                spacing: Math.max(root.height * 0.016, 10)

                CategoryBadge {
                    numPx: DisplayState.fontSize * root.numScale * root.numLayoutCentered
                    catScale: root.catScaleCentered
                    Layout.alignment: Qt.AlignHCenter
                    visible: DisplayState.categoryVisible
                }

                NowServingLabel {
                    Layout.alignment: Qt.AlignHCenter
                    visible: DisplayState.nowServingVisible
                }

                ServingNumber {
                    id: centered_number
                    layoutMult: root.numLayoutCentered
                    numScale: root.numScale
                    shownNumber: root._shownNumber
                    rootOpacity: root._numOpacity
                    rootScale: root._numScale
                    rootTranslateY: root._numTranslateY
                    Layout.alignment: Qt.AlignHCenter
                }

                AccentUnderline {
                    layoutMult: root.numLayoutCentered
                    numScale: root.numScale
                    rootOpacity: root._numOpacity
                    rootScale: root._numScale
                    rootTranslateY: root._numTranslateY
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text:           DisplayState.facilityName
                    font.family:    DisplayState.facilityFont || DisplayState.numberFont
                    font.pixelSize: Math.max(DisplayState.facilityFontSize || Math.max(root.height * 0.022, 10), 10)
                    font.weight:    Font.Light
                    color:          DisplayState.facilityColor
                    opacity:        DisplayState.facilityVisible ? 1.0 : 0.0
                    visible:        DisplayState.facilityVisible
                    style:          Text.Raised
                    styleColor:     Qt.rgba(0, 0, 0, 0.5)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ── Bottom banner ticker ────────────────────────────────────────
        // Centered previously had no banner at all. Added here, docked to
        // the bottom edge, matching the Classic/Split ticker so the banner
        // is always present, always moving, and always legible.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.max(root.height * 0.08, 36)
            color: Qt.rgba(0, 0, 0, 0.42)
            clip: true
            visible: DisplayState.bannerEnabled
            onWidthChanged: if (centered_ticker_anim) centered_ticker_anim.restart()

            Row {
                id: ticker_row_centered
                height: parent.height
                spacing: 0
                Repeater {
                    model: 3
                    Text {
                        height:            ticker_row_centered.height
                        verticalAlignment: Text.AlignVCenter
                        text:              DisplayState.bannerText + "   ·   "
                        font.family:       DisplayState.bannerFont || DisplayState.uiFont
                        font.pixelSize:    Math.max(DisplayState.bannerFontSize || Math.max(root.height * 0.023, 11), 11)
                        font.weight:       Font.DemiBold
                        color:             DisplayState.bannerColor
                        opacity:           0.9
                        style:             Text.Raised
                        styleColor:        Qt.rgba(0, 0, 0, 0.6)
                    }
                }
                NumberAnimation on x {
                    id: centered_ticker_anim
                    from: 0; to: -(ticker_row_centered.width / 3)
                    duration: 16000
                    loops: Animation.Infinite
                    running: DisplayState.bannerEnabled; easing.type: Easing.Linear
                }
            }
        }
    }
}
