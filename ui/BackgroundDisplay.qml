import QtQuick 2.15
import QtMultimedia
import "global"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property int _bgFillMode: Image.PreserveAspectCrop
    property string _pendingVideoSource: ""
    property string _lastGoodVideoSource: ""
    property bool _videoRecoveryInProgress: false
    property int _videoFailCount: 0
    readonly property int _maxVideoFailRetries: 2

    function resolveBackgroundFillMode(target) {
        var mode = DisplayState.backgroundFitMode
        if (mode === "fit") return Image.PreserveAspectFit
        if (mode === "stretch") return Image.Stretch
        return Image.PreserveAspectCrop
    }

    function updateBackgroundFitMode() {
        _bgFillMode = resolveBackgroundFillMode(backgroundImage)
    }

    function videoSourceForState() {
        if (DisplayState.backgroundType !== "video") return ""
        var src = DisplayState.backgroundVideoSource || ""
        if (!src) return ""
        if (src.startsWith("file://") || src.startsWith("http://") || src.startsWith("https://")) return src
        if (src.startsWith("/")) return DisplayState.publicUrl.replace(/\/$/, "") + src
        return src
    }

    function fallBackToImageBackground() {
        console.log("[display] video recovery exhausted — falling back to image background")
        _pendingVideoSource = ""
        _videoRecoveryInProgress = false
        _videoFailCount = 0
        player.stop()
        player.source = ""
    }

    function reloadBackgroundVideo() {
        if (DisplayState.backgroundType !== "video") return
        var src = videoSourceForState()
        if (!src) return

        if (player.source.toString() === src) {
            if (player.playbackState !== MediaPlayer.PlayingState) player.play()
            return
        }

        _pendingVideoSource = src

        // Force a real property transition if the player already holds this source
        if (player.source.toString() === src) {
            player.source = ""
        }

        player.source = src
        player.play()
    }

    function onVideoMediaStatus(mediaStatus) {
        if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
            _lastGoodVideoSource = player.source.toString()
            _videoFailCount = 0
            _pendingVideoSource = ""
        } else if (mediaStatus === MediaPlayer.InvalidMedia) {
            handleVideoLoadFailure(player.source.toString())
        }
    }

    function handleVideoLoadFailure(failedSrc) {
        _videoFailCount += 1

        if (_pendingVideoSource !== "") {
            reloadBackgroundVideo()
            return
        }

        if (_videoFailCount > _maxVideoFailRetries) {
            fallBackToImageBackground()
            return
        }

        if (_lastGoodVideoSource && _lastGoodVideoSource !== failedSrc) {
            console.log("[display] video failed, recovering to last-good source")
            _videoRecoveryInProgress = true
            player.source = _lastGoodVideoSource
            player.play()
            return
        }

        fallBackToImageBackground()
    }

    function updateBackground() {
        updateBackgroundFitMode()

        if (DisplayState.backgroundType === "video") {
            reloadBackgroundVideo()
        } else {
            player.stop()
            _pendingVideoSource = ""
            _videoRecoveryInProgress = false
            _videoFailCount = 0
        }
    }

    Component.onCompleted: updateBackground()

    Connections {
        target: DisplayState
        function onBackgroundFitModeChanged() { root.updateBackground() }
        function onBackgroundImageChanged() { root.updateBackground() }
        function onBackgroundScaleChanged() { root.updateBackground() }
        function onBackgroundOffsetXChanged() { root.updateBackground() }
        function onBackgroundOffsetYChanged() { root.updateBackground() }
        function onBackgroundTypeChanged() { root.updateBackground() }
        function onBackgroundVideoSourceChanged() { root.updateBackground() }
    }

    Image {
        id: backgroundImage
        anchors.fill: parent
        opacity: DisplayState.backgroundType !== "video" ? 1 : 0
        source: DisplayState.backgroundType === "video" ? "" : DisplayState.backgroundImage
        fillMode: root._bgFillMode
        asynchronous: true
        cache: true
        smooth: true
        sourceSize.width: root.width
        sourceSize.height: root.height
        scale: DisplayState.backgroundScale
        transformOrigin: Item.Center
        transform: Translate {
            x: DisplayState.backgroundOffsetX
            y: DisplayState.backgroundOffsetY
        }
        onStatusChanged: root.updateBackgroundFitMode()
        onSourceSizeChanged: root.updateBackgroundFitMode()
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        }
    }

    MediaPlayer {
        id: player
        loops: MediaPlayer.Infinite
        audioOutput: null
        videoOutput: videoOutput
        onErrorOccurred: function(errorString, error) {
            root.handleVideoLoadFailure(source.toString())
        }
        onMediaStatusChanged: root.onVideoMediaStatus(mediaStatus)
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        opacity: (DisplayState.backgroundType === "video" && player.playbackState === MediaPlayer.PlayingState) ? 1 : 0
        fillMode: DisplayState.backgroundFitMode === "stretch" ? VideoOutput.Stretch
                  : (DisplayState.backgroundFitMode === "fit" ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop)
        scale: DisplayState.backgroundScale
        transformOrigin: Item.Center
        transform: Translate { x: DisplayState.backgroundOffsetX; y: DisplayState.backgroundOffsetY }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    }

    Item {
        anchors.centerIn: parent
        visible: DisplayState.backgroundType === "video" && player.playbackState !== MediaPlayer.PlayingState
        width: 60
        height: 60

        Rectangle {
            anchors.centerIn: parent
            width: 48
            height: 48
            radius: 24
            color: "transparent"
            border { width: 4; color: DisplayState.accentColor }
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: parent.visible
            }
        }
    }
}
