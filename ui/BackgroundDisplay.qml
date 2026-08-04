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
    property int _videoLoadingSlot: -1
    property int _activeVideoSlot: 0

    Timer {
        id: videoSwapStopTimer
        property int oldSlot: -1
        interval: 400
        repeat: false
        onTriggered: {
            if (oldSlot >= 0) playerFor(oldSlot).stop()
        }
    }

    function resolveBackgroundFillMode(target) {
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
        _videoLoadingSlot = -1
        player0.stop()
        player0.source = ""
        player1.stop()
        player1.source = ""
    }

    function playerFor(slot) {
        return slot === 0 ? player0 : player1
    }

    function reloadBackgroundVideo() {
        if (DisplayState.backgroundType !== "video") return
        var src = videoSourceForState()
        if (!src) return

        var activePlayer = playerFor(_activeVideoSlot)
        if (activePlayer.source.toString() === src) {
            if (activePlayer.playbackState !== MediaPlayer.PlayingState) activePlayer.play()
            return
        }

        var loadingSlot = _activeVideoSlot === 0 ? 1 : 0
        var loadingPlayer = playerFor(loadingSlot)
        _pendingVideoSource = src
        _videoLoadingSlot = loadingSlot
        loadingPlayer.source = src
        loadingPlayer.play()
    }

    function onVideoMediaStatus(slot, mediaStatus) {
        if (slot !== _videoLoadingSlot) return

        if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
            _lastGoodVideoSource = playerFor(slot).source.toString()
            _videoFailCount = 0
            var oldSlot = _activeVideoSlot
            _activeVideoSlot = slot
            _videoLoadingSlot = -1
            videoSwapStopTimer.oldSlot = oldSlot
            videoSwapStopTimer.restart()
        } else if (mediaStatus === MediaPlayer.InvalidMedia) {
            handleVideoLoadFailure(playerFor(slot).source.toString())
        }
    }

    function handleVideoLoadFailure(failedSrc) {
        _videoLoadingSlot = -1
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
            var loadingSlot = _activeVideoSlot === 0 ? 1 : 0
            _videoLoadingSlot = loadingSlot
            playerFor(loadingSlot).source = _lastGoodVideoSource
            playerFor(loadingSlot).play()
            return
        }

        fallBackToImageBackground()
    }

    function updateBackground() {
        updateBackgroundFitMode()

        if (DisplayState.backgroundType === "video") {
            reloadBackgroundVideo()
        } else {
            player0.stop()
            player1.stop()
            _pendingVideoSource = ""
            _videoRecoveryInProgress = false
            _videoFailCount = 0
            _videoLoadingSlot = -1
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
        cache: false
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
        // Behavior on opacity {
        //     NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        // }
    }

    MediaPlayer {
        id: player0
        loops: MediaPlayer.Infinite
        audioOutput: null
        videoOutput: output0
        onErrorOccurred: function(errorString, error) {
            root.handleVideoLoadFailure(source.toString())
        }
        onMediaStatusChanged: root.onVideoMediaStatus(0, mediaStatus)
    }

    MediaPlayer {
        id: player1
        loops: MediaPlayer.Infinite
        audioOutput: null
        videoOutput: output1
        onErrorOccurred: function(errorString, error) {
            root.handleVideoLoadFailure(source.toString())
        }
        onMediaStatusChanged: root.onVideoMediaStatus(1, mediaStatus)
    }

    VideoOutput {
        id: output0
        anchors.fill: parent
        opacity: (DisplayState.backgroundType === "video" && root._activeVideoSlot === 0
                  && player0.playbackState === MediaPlayer.PlayingState) ? 1 : 0
        fillMode: DisplayState.backgroundFitMode === "stretch" ? VideoOutput.Stretch
                  : (DisplayState.backgroundFitMode === "fit" ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop)
        scale: DisplayState.backgroundScale
        transformOrigin: Item.Center
        transform: Translate { x: DisplayState.backgroundOffsetX; y: DisplayState.backgroundOffsetY }
        // Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    }

    VideoOutput {
        id: output1
        anchors.fill: parent
        opacity: (DisplayState.backgroundType === "video" && root._activeVideoSlot === 1
                  && player1.playbackState === MediaPlayer.PlayingState) ? 1 : 0
        fillMode: DisplayState.backgroundFitMode === "stretch" ? VideoOutput.Stretch
                  : (DisplayState.backgroundFitMode === "fit" ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop)
        scale: DisplayState.backgroundScale
        transformOrigin: Item.Center
        transform: Translate { x: DisplayState.backgroundOffsetX; y: DisplayState.backgroundOffsetY }
        // Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    }

    Item {
        anchors.centerIn: parent
        visible: DisplayState.backgroundType === "video"
                 && player0.playbackState !== MediaPlayer.PlayingState
                 && player1.playbackState !== MediaPlayer.PlayingState
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
