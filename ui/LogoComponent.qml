import QtQuick 2.15
import "global"

Item {
    id: logoRoot
    property real baseSize: DisplayState.logoSize
    property real layoutMult: 1.0
    property real logoBottom: logoContainer.y + logoContainer.height

    visible: DisplayState.logoVisible && DisplayState.logoPosition !== "hidden"
    opacity: visible ? 1 : 0

    // Positioning based on logoPosition
    anchors.top: parent.top
    anchors.topMargin: Math.max(logoRoot.parent ? logoRoot.parent.height * 0.04 : 0, 16)

    // Horizontal positioning - use x for left, anchors.horizontalCenter for center
    x: {
        if (!logoRoot.parent) return 0;
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
        radius: 12
        color: Qt.rgba(DisplayState.accentColor.r,
                       DisplayState.accentColor.g,
                       DisplayState.accentColor.b, 0.15)
        Behavior on color { ColorAnimation { duration: 600 } }

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
