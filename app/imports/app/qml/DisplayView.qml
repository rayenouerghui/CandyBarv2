import QtQuick 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0
import "global"
import QtMultimedia

// ── DisplayView ──────────────────────────────────────────────────────────
// The permanent, always-on display. Hosts Classic, Split, and Centered layouts.
// All three stay in the tree; opacity crossfade switches between them.
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

    // RTL mirroring — automatically mirrors Row/RowLayout children when
    // displayLanguage is Arabic. Individual text items use their own
    // horizontal alignment so they are unaffected by mirroring.
    LayoutMirroring.enabled:  DisplayState.isRtl
    LayoutMirroring.childrenInherit: true

    // ── Timing constants ─────────────────────────────────────────────────
    readonly property int dur_micro: 150   // number exit
    readonly property int dur_std:   300   // number entrance / state transitions
    readonly property int dur_full:  600   // layout crossfade / color transitions

    // ── Radius tokens ────────────────────────────────────────────────────
    readonly property int radius_outer: 20
    readonly property int radius_card:  14
    readonly property int radius_chip:  12

    // ── Typography scale ─────────────────────────────────────────────────
    // numScale: multiplier so the number fills the screen proportionally
    readonly property real numScale: Math.max(root.height / 480.0, 0.8)

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
    Behavior on accent_gold {
        ColorAnimation {
            duration: root.dur_full
            easing.type: Easing.InOutQuad
        }
    }

    // Glass card behind the whole number+category stack — a soft, neutral
    // dark scrim that guarantees a stable contrast surface no matter what
    // photo is loaded as the background.
    readonly property color glass_fill:   Qt.rgba(0, 0, 0, 0.32)
    readonly property color glass_border: Qt.rgba(1, 1, 1, 0.14)
    readonly property color glass_shadow: Qt.rgba(0, 0, 0, 0.28)
    readonly property color glass_highlight: Qt.rgba(1, 1, 1, 0.08)



    // ── Shared components ────────────────────────────────────────────────

    // LogoComponent: handles positioning and aspect ratio for the logo
    // Supports top-left, top-center, and hidden positions
    component LogoComponent: Item {
        id: logoRoot
        property real baseSize: DisplayState.logoSize
        property real layoutMult: 1.0

        visible: DisplayState.logoVisible && DisplayState.logoPosition !== "hidden"
        opacity: visible ? 1 : 0

        // Positioning based on logoPosition
        anchors.top: parent.top
        anchors.topMargin: Math.max(logoRoot.parent.height * 0.04, 16)

        // Horizontal positioning - use x for left, anchors.horizontalCenter for center
        x: {
            if (DisplayState.logoPosition === "top-left") {
                return Math.max(logoRoot.parent.width * 0.04, 16)
            } else if (DisplayState.logoPosition === "top-center") {
                return (logoRoot.parent.width - logoContainer.width) / 2
            }
            return 0
        }

        // Logo container with proper aspect ratio
        Rectangle {
            id: logoContainer
            property real aspectRatio: 1.0

            width: {
                if (aspectRatio > 1) {
                    return baseSize * layoutMult * aspectRatio
                } else {
                    return baseSize * layoutMult
                }
            }
            height: {
                if (aspectRatio > 1) {
                    return baseSize * layoutMult
                } else {
                    return baseSize * layoutMult / aspectRatio
                }
            }
            radius: root.radius_chip
            color: root.accent_gold_dim
            Behavior on color { ColorAnimation { duration: root.dur_full } }

            // Load image to get natural aspect ratio
            Image {
                id: logoLoader
                source: DisplayState.logoSource
                visible: false
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Ready && sourceSize.width > 0 && sourceSize.height > 0) {
                        // Set aspect ratio for reactive sizing
                        logoContainer.aspectRatio = sourceSize.width / sourceSize.height
                    }
                }
            }

            Image {
                anchors { fill: parent; margins: Math.max(3, baseSize * 0.07) }
                source: DisplayState.logoSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize: Qt.size(baseSize * 2 * layoutMult, baseSize * 2 * layoutMult)
            }
        }
    }

    // CategoryBadge: redesigned from a thick, fully-rounded "pill/counter chip"
    // into a refined rectangular tag — a left accent bar + small dot instead
    // of a heavy colored outline, softer neutral glass fill, tighter corners.
    // This reads as a proper category label rather than a counter-style badge.
    component CategoryBadge: Item {
    property real numPx: 96
    property real catScale: 0.34

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
        radius: root.radius_card
        color: Qt.rgba(0, 0, 0, 0.34)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 6
            color: root.accent_gold
            Behavior on color { ColorAnimation { duration: root.dur_full } }
        }
    }

    RowLayout {
        id: catRow
        anchors {
            left: parent.left
            leftMargin: parent._leftPad
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 10
            height: 10
            radius: 5
            color: root.accent_gold
            Behavior on color { ColorAnimation { duration: root.dur_full } }
        }

        Item {
            Layout.maximumWidth: root.width * 0.9
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

    // NowServingLabel: still the smallest tier, but now clearly readable —
    // bumped from Font.Light to Font.Bold, higher opacity, and pure white
    // instead of the tinted secondary color so it doesn't wash out against
    // any background. Text is translated via DisplayState.tr().
    component NowServingLabel: Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: labelText.implicitWidth
        Layout.preferredHeight: labelText.implicitHeight

        Text {
            id: shadowLabel1
            anchors.centerIn: parent
            text: DisplayState.tr("now_serving")
            font.family: DisplayState.nowServingFont || DisplayState.numberFont
            font.pixelSize: Math.max(DisplayState.nowServingFontSize || Math.max(root.height * 0.021, 11), 10)
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
            font.pixelSize: Math.max(DisplayState.nowServingFontSize || Math.max(root.height * 0.021, 11), 10)
            font.letterSpacing: 5
            font.weight: Font.Bold
            color: DisplayState.nowServingColor
            opacity: 0.98
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.85)
        }
    }

    // ServingNumber: the dominant element — maximum weight, animated
    component ServingNumber: Item {
        property real layoutMult: 1.0

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth:  numText.implicitWidth
        Layout.preferredHeight: numText.implicitHeight
        opacity: root._numOpacity
        scale:   root._numScale
        transformOrigin: Item.Center
        transform: Translate { y: root._numTranslateY }

        // Single shadow for performance
        Text {
            anchors.centerIn: parent
            text: root._shownNumber
            font.family:       DisplayState.numberFont
            font.pixelSize:    Math.max(DisplayState.numberFontSize || (DisplayState.fontSize * root.numScale * layoutMult), 12)
            font.weight:       Font.Black
            font.letterSpacing: root.numLetterSpacing
            renderType:        Text.NativeRendering
            color:             Qt.rgba(0, 0, 0, 0.85)
            anchors.topMargin: 4
            anchors.leftMargin: 2
        }
        // Main text
        Text {
            id: numText
            anchors.centerIn: parent
            text: root._shownNumber
            font.family:       DisplayState.numberFont
            font.pixelSize:    Math.max(DisplayState.numberFontSize || (DisplayState.fontSize * root.numScale * layoutMult), 12)
            font.weight:       Font.Black   // heaviest available weight
            font.letterSpacing: root.numLetterSpacing
            renderType:        Text.NativeRendering
            color:             DisplayState.numberColor
            style:             Text.Raised
            styleColor:        Qt.rgba(0, 0, 0, 0.9)
        }
    }

    // AccentUnderline ("candy bar"): ties number+category together visually.
    // DESIGN CHANGE: was 4px and could fade to fully transparent on one end
    // via the gradient, making it read as invisible. Now it's thicker (8px),
    // sits on a soft glow layer for extra contrast, and the gradient never
    // drops below a visible minimum opacity — it tapers, it doesn't vanish.
    component AccentUnderline: Item {
        property real layoutMult: 1.0

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth:  glow.width
        Layout.preferredHeight: glow.height
        opacity: root._numOpacity
        scale:   root._numScale
        transformOrigin: Item.Center
        transform: Translate { y: root._numTranslateY * 0.35 }

        // Soft glow layer behind the bar — wider + softer, boosts perceived
        // contrast without changing the bar's crisp shape.
        Rectangle {
            id: glow
            anchors.centerIn: parent
            width:  bar.width + 24
            height: 14
            radius: height / 2
            color: Qt.rgba(root.accent_gold.r, root.accent_gold.g, root.accent_gold.b, 0.35)
        }

        Rectangle {
            id: bar
            anchors.centerIn: parent
            width:  Math.max(56, DisplayState.fontSize * root.numScale * layoutMult * 0.46)
            height: 8
            radius: 4
            color: DisplayState.accentGradientEnabled ? "transparent" : root.accent_gold
            gradient: DisplayState.accentGradientEnabled ? accentGrad : null
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)
            Gradient {
                id: accentGrad
                orientation: DisplayState.accentGradientDirection === "top-to-bottom"
                             ? Gradient.Vertical : Gradient.Horizontal
                // Tapers to a dimmed version of the accent color instead of
                // full transparency, so the bar never has an invisible end.
                GradientStop { position: 0.0; color: root.accent_gold }
                GradientStop { position: 1.0; color: Qt.rgba(root.accent_gold.r, root.accent_gold.g, root.accent_gold.b, 0.35) }
            }
            Behavior on color { ColorAnimation { duration: root.dur_full } }
        }
    }

    // ── Background ───────────────────────────────────────────────────────
    property int _bgFillMode: Image.PreserveAspectCrop

    function _resolveBackgroundFillMode(target) {
        var mode = DisplayState.backgroundFitMode
        if (mode === "fit") return Image.PreserveAspectFit
        if (mode === "stretch") return Image.Stretch
        if (mode === "auto") {
            if (target && target.status === Image.Ready && target.sourceSize.width > 0 && target.sourceSize.height > 0) {
                var imgRatio = target.sourceSize.width / target.sourceSize.height
                var screenRatio = root.width / Math.max(1, root.height)
                return Math.abs(imgRatio - screenRatio) > 0.25 ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            }
            return Image.PreserveAspectCrop
        }
        return Image.PreserveAspectCrop
    }

    function _updateBackgroundFitMode() {
        _bgFillMode = _resolveBackgroundFillMode(background_image)
    }

    function _videoSourceForState() {
        if (DisplayState.backgroundType !== "video") return ""
        var src = DisplayState.backgroundVideoSource || ""
        if (!src) return ""
        if (src.startsWith("file://") || src.startsWith("http://") || src.startsWith("https://")) return src
        if (src.startsWith("/")) return DisplayState.publicUrl.replace(/\/$/, "") + src
        return src
    }

    function _reloadBackgroundVideo() {
        if (DisplayState.backgroundType !== "video") return
        var src = root._videoSourceForState()
        console.log("[display] reload background video", DisplayState.backgroundType, src)
        if (!src) return
        
        // Use a more efficient approach without stopping first if source is the same
        if (background_video_player.source !== src) {
            background_video_player.stop()
            background_video_player.source = src
        }
        background_video_player.play()
    }

    Item {
        id: background_layer
        anchors.fill: parent
        clip: true

        Image {
            id: background_image
            anchors.fill: parent
            opacity: DisplayState.backgroundType !== "video" ? 1 : 0
            source: DisplayState.backgroundType === "video" ? "" : DisplayState.backgroundImage
            fillMode: root._bgFillMode
            asynchronous: false
            cache: false
            smooth: true
            scale: DisplayState.backgroundScale
            transformOrigin: Item.Center
            transform: Translate {
                x: DisplayState.backgroundOffsetX
                y: DisplayState.backgroundOffsetY
            }
            onStatusChanged: root._updateBackgroundFitMode()
            onSourceSizeChanged: root._updateBackgroundFitMode()
            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
            }
        }

        MediaPlayer {
            id: background_video_player
            source: root._videoSourceForState()
            loops: MediaPlayer.Infinite
            audioOutput: null
            videoOutput: background_video_output
            onSourceChanged: {
                console.log("[display] video source changed:", source)
                if (source.toString() !== "" && DisplayState.backgroundType === "video") {
                    play()
                }
            }
            onErrorOccurred: function(errorString, error) {
                console.log("[display] background video error:", errorString, "source:", source, "error:", error)
            }
            onPlaybackStateChanged: {
                console.log("[display] playback state:", playbackState)
            }
        }

        VideoOutput {
            id: background_video_output
            anchors.fill: parent
            opacity: (DisplayState.backgroundType === "video" && 
                     background_video_player.playbackState === MediaPlayer.PlayingState) ? 1 : 0
            fillMode: DisplayState.backgroundFitMode === "stretch"
                      ? VideoOutput.Stretch
                      : (DisplayState.backgroundFitMode === "fit"
                         ? VideoOutput.PreserveAspectFit
                         : VideoOutput.PreserveAspectCrop)
            scale: DisplayState.backgroundScale
            transformOrigin: Item.Center
            transform: Translate {
                x: DisplayState.backgroundOffsetX
                y: DisplayState.backgroundOffsetY
            }
            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
            }
        }

        // Video loading indicator
        Item {
            anchors.centerIn: parent
            visible: DisplayState.backgroundType === "video" && 
                     (background_video_player.playbackState === MediaPlayer.LoadingState || 
                      background_video_player.playbackState === MediaPlayer.StoppedState || 
                      background_video_player.playbackState === MediaPlayer.PausedState)
            width: 60; height: 60
            
            Rectangle {
                id: loaderRect
                anchors.centerIn: parent
                width: 48; height: 48
                radius: 24
                color: "transparent"
                border {
                    width: 4
                    color: root.accent_gold
                }
                
                RotationAnimator on rotation {
                    from: 0; to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: parent.visible
                }
            }
        }
    }

    function _updateBackground() {
        // Handle both image and video backgrounds
        root._updateBackgroundFitMode()
        
        if (DisplayState.backgroundType === "video") {
            root._reloadBackgroundVideo()
        } else {
            // Stop video playback when switching to image background
            background_video_player.stop()
        }
    }

    Connections {
        target: DisplayState
        function onBackgroundFitModeChanged() { root._updateBackground() }
        function onBackgroundImageChanged() { root._updateBackground() }
        function onBackgroundScaleChanged() { root._updateBackground() }
        function onBackgroundOffsetXChanged() { root._updateBackground() }
        function onBackgroundOffsetYChanged() { root._updateBackground() }
        function onBackgroundTypeChanged() { root._updateBackground() }
        function onBackgroundVideoSourceChanged() { root._updateBackground() }
    }

    // Dark scrim — enough for text contrast, not so much it kills the image
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
    }

    // ── Number change animation ──────────────────────────────────────────
    // Phase 1 (exit): lift + shrink + fade  →  150ms InCubic
    // Phase 2 (enter): drop in + grow + fade →  300ms OutQuart
    property string _shownNumber:   DisplayState.currentNumber
    property real   _numOpacity:    1.0
    property real   _numScale:      1.0
    property real   _numTranslateY: 0

    readonly property real _numOutScale:    0.86
    readonly property real _numInFromScale: 0.90
    readonly property real _numOutLift:     Math.max(root.height * 0.022, 8)
    readonly property real _numInDrop:      Math.max(root.height * 0.028, 10)

    function _resetNumberAnim() {
        _numOpacity    = 1.0
        _numScale      = 1.0
        _numTranslateY = 0
    }

    onVisibleChanged: {
        if (visible) {
            _shownNumber = DisplayState.currentNumber
            _resetNumberAnim()
        }
    }

    Connections {
        target: DisplayState
        function onCurrentNumberChanged() {
            if (_shownNumber === DisplayState.currentNumber) return
            num_change_anim.stop()
            num_change_anim.start()
        }
    }

    SequentialAnimation {
        id: num_change_anim
        alwaysRunToEnd: false

        ParallelAnimation {
            NumberAnimation { target: root; property: "_numOpacity";    to: 0;                duration: root.dur_micro; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_numScale";      to: root._numOutScale; duration: root.dur_micro; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "_numTranslateY"; to: -root._numOutLift; duration: root.dur_micro; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                root._shownNumber   = DisplayState.currentNumber
                root._numTranslateY = root._numInDrop
                root._numScale      = root._numInFromScale
                root._numOpacity    = 0
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "_numOpacity";    to: 1;   duration: root.dur_std; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "_numScale";      to: 1.0; duration: root.dur_std; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "_numTranslateY"; to: 0;   duration: root.dur_std; easing.type: Easing.OutQuart }
        }
    }

    // ── Layout crossfade controller ──────────────────────────────────────
    property real _splitOpacity:    0
    property real _centeredOpacity: 1
    property real _topOpacity:      0

    Behavior on _splitOpacity    { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }
    Behavior on _centeredOpacity { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }
    Behavior on _topOpacity      { NumberAnimation { duration: dur_full; easing.type: Easing.OutCubic } }

    function _applyLayout(lt) {
         _splitOpacity    = (lt === "Split")    ? 1 : 0
         _centeredOpacity = (lt === "Centered") ? 1 : 0
         _topOpacity      = (lt === "Top")      ? 1 : 0
         if (lt === "Split"    && split_ticker_anim)    split_ticker_anim.restart()
         if (lt === "Top"      && top_ticker_anim)      top_ticker_anim.restart()
         if (lt === "Centered" && centered_ticker_anim) centered_ticker_anim.restart()
    }

    Connections {
        target: DisplayState
        function onLayoutTypeChanged() { root._applyLayout(DisplayState.layoutType) }
    }

    Component.onCompleted: _applyLayout(DisplayState.layoutType)



    // ════════════════════════════════════════════════════════════════════
    // SPLIT LAYOUT
    // Left 55%:  glass card ▸ logo → NowServingLabel → CategoryBadge → Number → Underline
    // Right 45%: "NEXT UP" queue (clearly subordinate)
    // ════════════════════════════════════════════════════════════════════
    Item {
        id: split_layout
        anchors.fill: parent
        opacity: root._splitOpacity
        visible: opacity > 0
        onVisibleChanged: {
        if (visible && split_ticker_anim) split_ticker_anim.restart()
        }

        // Logo — positioned absolutely based on logoPosition (full width)
        LogoComponent {
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

                // Left panel content column — no glass card
                ColumnLayout {
                    id: split_content_col
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: root.numOpticalLift
                    spacing: 0

                    // Whisper
                    NowServingLabel {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Math.max(root.height * 0.012, 8)
                    }

                    // Category — badge
                    CategoryBadge {
                        numPx: DisplayState.fontSize * root.numScale * root.numLayoutSplit
                        catScale: root.catScaleSplit
                        Layout.bottomMargin: Math.max(root.height * 0.016, 10)
                    }

                    // Number
                    ServingNumber {
                        layoutMult: root.numLayoutSplit
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Math.max(root.height * 0.014, 8)
                    }

                    // Underline
                    AccentUnderline {
                        layoutMult: root.numLayoutSplit
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Math.max(root.height * 0.016, 10)
                    }

                    // Facility name
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: DisplayState.facilityName
                        font.family: DisplayState.facilityFont || DisplayState.numberFont
                        font.pixelSize: Math.max(DisplayState.facilityFontSize || Math.max(root.height * 0.022, 10), 10)
                        font.weight: Font.Light
                        color: DisplayState.facilityColor
                        opacity: 1.0
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.5)
                    }
                }
            }

            // ── Right panel — next-up queue (subordinate) ─────────────────
            Item {
                width:  parent.width * 0.45
                height: parent.height

                ColumnLayout {
                    anchors { fill: parent; margins: 28; topMargin: 44 }
                    spacing: 20

                    // "NEXT UP" — clearly secondary, small and dim
                    Text {
                        text:           DisplayState.tr("next_up")
                        font.family:    DisplayState.uiFont
                        font.pixelSize: Math.max(root.height * 0.048, 24)
                        font.letterSpacing: 5
                        font.weight:    Font.Bold
                        color:          root.text_secondary
                        opacity:        0.85
                        Layout.bottomMargin: 20
                        style:          Text.Raised
                        styleColor:     Qt.rgba(0, 0, 0, 0.5)
                    }

                    Repeater {
                        model: {
                            var nu = DisplayState.nextUp
                            if (nu && nu.length > 0) return nu.slice(0, 4)
                            var base = parseInt(DisplayState.currentNumber) || 0
                            var arr = []
                            for (var i = 1; i <= 4; i++)
                                arr.push(String(base + i).padStart(3, '0'))
                            return arr
                        }

                        delegate: Item {
                            Layout.fillWidth: true
                            height: nextNumText.implicitHeight + 32

                            Text {
                                id: nextNumText
                                anchors {
                                    left: parent.left; leftMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text:           modelData
                                font.family:    DisplayState.numberFont
                                font.pixelSize: Math.max(root.height * 0.12, 60)
                                font.weight:    Font.Bold
                                color:          root.text_primary
                                opacity:        0.85 - index * 0.15
                                style:          Text.Raised
                                styleColor:     Qt.rgba(0, 0, 0, 0.55)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Banner strip at bottom of right panel — converted to
                    // a scrolling ticker (matching Classic) inside its own
                    // contrast pill, since static wrapped text at low
                    // opacity was easy to miss. Always animating.
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
                                duration: 14000; loops: Animation.Infinite
                                running: true; easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // TOP LAYOUT
    // A simple top-aligned layout so the Top option always renders a
    // visible stack instead of leaving only the background on screen.
    // ════════════════════════════════════════════════════════════════════
   Item {
    id: top_layout
    anchors.fill: parent
    opacity: root._topOpacity
    visible: opacity > 0
    onVisibleChanged: {
        if (visible && top_ticker_anim) top_ticker_anim.restart()
    }

    LogoComponent {
        baseSize: DisplayState.logoSize
        layoutMult: 0.9
    }

    // ── Header strip — label + category side-by-side, NOT stacked ──────
    // This is what makes Top structurally different from Centered: instead
    // of a vertical stack, the secondary info is compressed into one slim
    // horizontal row, freeing almost the whole screen for the number.
    RowLayout {
        id: top_header_row
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: Math.max(root.height * 0.05, 20)
        }
        spacing: Math.max(root.width * 0.03, 20)

        NowServingLabel {}

        CategoryBadge {
            numPx: DisplayState.fontSize * root.numScale * root.numLayoutTop
            catScale: root.catScaleTop
        }
    }

    // ── Hero number — fills essentially the whole remaining screen ─────
    Item {
        id: top_hero_area
        anchors {
            top: top_header_row.bottom
            left: parent.left
            right: parent.right
            bottom: top_facility_text.top
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            ServingNumber {
                layoutMult: root.numLayoutTop
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Math.max(root.height * 0.02, 12)
            }

            AccentUnderline {
                layoutMult: root.numLayoutTop
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    Text {
        id: top_facility_text
        anchors {
            bottom: top_banner.top
            horizontalCenter: parent.horizontalCenter
            bottomMargin: Math.max(root.height * 0.014, 8)
        }
        text: DisplayState.facilityName
        font.family: DisplayState.facilityFont || DisplayState.numberFont
        font.pixelSize: Math.max(DisplayState.facilityFontSize || Math.max(root.height * 0.022, 10), 10)
        font.weight: Font.Light
        color: DisplayState.facilityColor
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.5)
    }

    Rectangle {
        id: top_banner
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.max(root.height * 0.08, 36)
        color: Qt.rgba(0, 0, 0, 0.42)
        clip: true
        visible: DisplayState.bannerEnabled
        onWidthChanged: if (top_ticker_anim) top_ticker_anim.restart()

        Row {
            id: ticker_row_top
            height: parent.height
            spacing: 0
            Repeater {
                model: 3
                Text {
                    height: ticker_row_top.height
                    verticalAlignment: Text.AlignVCenter
                    text: DisplayState.bannerText + "   ·   "
                    font.family: DisplayState.bannerFont || DisplayState.uiFont
                    font.pixelSize: Math.max(DisplayState.bannerFontSize || Math.max(root.height * 0.023, 11), 11)
                    font.weight: Font.DemiBold
                    color: DisplayState.bannerColor
                    opacity: 0.9
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                }
            }
            NumberAnimation on x {
                id: top_ticker_anim
                from: 0; to: -(ticker_row_top.width / 3)
                duration: 16000; loops: Animation.Infinite
                running: true; easing.type: Easing.Linear
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
            baseSize: DisplayState.logoSize
            layoutMult: 1.25
        }

        // Centered layout content — no glass card
        ColumnLayout {
            id: centered_content_col
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.numOpticalLift
            spacing: 0

            // Whisper
            NowServingLabel {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Math.max(root.height * 0.012, 8)
            }

            // Category — badge, largest of the three layouts
            CategoryBadge {
                numPx: DisplayState.fontSize * root.numScale * root.numLayoutCentered
                catScale: root.catScaleCentered
                Layout.bottomMargin: Math.max(root.height * 0.018, 12)
            }

            // Number — biggest of all three layouts
            ServingNumber {
                layoutMult: root.numLayoutCentered
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Math.max(root.height * 0.016, 10)
            }

            // Underline
            AccentUnderline {
                layoutMult: root.numLayoutCentered
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Math.max(root.height * 0.030, 16)
            }

            // Facility name — tertiary, bottom of stack
            Text {
                Layout.alignment: Qt.AlignHCenter
                text:           DisplayState.facilityName
                font.family:    DisplayState.facilityFont || DisplayState.numberFont
                font.pixelSize: Math.max(DisplayState.facilityFontSize || Math.max(root.height * 0.022, 10), 10)
                font.weight:    Font.Light
                color:          DisplayState.facilityColor
                opacity:        1.0
                style:          Text.Raised
                styleColor:     Qt.rgba(0, 0, 0, 0.5)
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
                    duration: 16000; loops: Animation.Infinite
                    running: true; easing.type: Easing.Linear
                }
            }
        }
    }
}
