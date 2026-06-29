import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import FluentUI 1.0
import "../global"

FluPage {
    title: "Display"

    Component.onCompleted: {
        if (typeof NetworkHelper !== "undefined")
            DisplayState.adminUrl = NetworkHelper.adminUrl
    }

    Connections {
        target: MqttClient
        function onDisplayCommandReceived(key, value) {
            DisplayState.applyMqttCommand(key, value)
        }
    }

    // ── full-page display area ────────────────────────────────────────────
    Item {
        id: display_root
        anchors.fill: parent

        // background
        Rectangle {
            anchors.fill: parent
            color: DisplayState.backgroundColor
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        // ── CLASSIC layout ────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: DisplayState.layoutType === "Classic"

            Rectangle {
                id: header_bar
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(display_root.height * 0.14, 60)
                color: DisplayState.headerColor
                Behavior on color { ColorAnimation { duration: 400 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 28; rightMargin: 28 }
                    spacing: 16
                    Rectangle {
                        width: 52; height: 52; radius: 8
                        color: Qt.rgba(1, 1, 1, 0.15)
                        Image {
                            anchors { fill: parent; margins: 4 }
                            source: DisplayState.logoSource
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(120, 120)
                        }
                    }
                    Text {
                        text: DisplayState.facilityName
                        font.family: DisplayState.fontFamily
                        font.pixelSize: Math.max(display_root.height * 0.032, 14)
                        font.weight: Font.Medium
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        id: clock_text
                        font.family: DisplayState.fontFamily
                        font.pixelSize: Math.max(display_root.height * 0.028, 13)
                        color: Qt.rgba(1, 1, 1, 0.85)
                        text: Qt.formatTime(new Date(), "hh:mm:ss")
                    }
                    Timer {
                        interval: 1000; repeat: true; running: true
                        onTriggered: clock_text.text = Qt.formatTime(new Date(), "hh:mm:ss")
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "NOW SERVING"
                        font.family: DisplayState.fontFamily
                        font.pixelSize: Math.max(display_root.height * 0.038, 16)
                        font.letterSpacing: 6
                        font.weight: Font.Light
                        color: DisplayState.textColor
                        opacity: 0.65
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    Text {
                        id: number_display
                        text: DisplayState.currentNumber
                        font.family: DisplayState.fontFamily
                        font.pixelSize: DisplayState.fontSize * (display_root.height / 480)
                        font.weight: Font.Bold
                        color: DisplayState.numberColor
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 400 } }
                        scale: 1.0
                        SequentialAnimation on scale {
                            id: number_pop
                            running: false
                            NumberAnimation { to: 1.18; duration: 120; easing.type: Easing.OutCubic }
                            NumberAnimation { to: 1.0;  duration: 200; easing.type: Easing.OutBounce }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation { to: 0.88; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0;  duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: number_display.implicitWidth * 0.9
                        height: 4; radius: 2
                        color: DisplayState.accentColor
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    Text {
                        text: "Please proceed to your counter"
                        font.family: DisplayState.fontFamily
                        font.pixelSize: Math.max(display_root.height * 0.028, 12)
                        color: DisplayState.textColor
                        opacity: 0.50
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(display_root.height * 0.12, 48)
                color: DisplayState.bannerBg
                Behavior on color { ColorAnimation { duration: 400 } }
                clip: true
                Row {
                    id: ticker_row
                    height: parent.height
                    spacing: 80
                    Repeater {
                        model: 3
                        Text {
                            height: ticker_row.height
                            verticalAlignment: Text.AlignVCenter
                            text: "✦  " + DisplayState.bannerText + "  "
                            font.family: DisplayState.fontFamily
                            font.pixelSize: Math.max(display_root.height * 0.032, 13)
                            color: DisplayState.bannerText_c
                            Behavior on color { ColorAnimation { duration: 400 } }
                        }
                    }
                    NumberAnimation on x {
                        from: 0
                        to: -(ticker_row.width / 3)
                        duration: 12000
                        loops: Animation.Infinite
                        running: true
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        // ── CENTERED layout ───────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: DisplayState.layoutType === "Centered"

            Rectangle {
                width: parent.width; height: 6
                color: DisplayState.accentColor
                Behavior on color { ColorAnimation { duration: 400 } }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: DisplayState.logoSource
                    fillMode: Image.PreserveAspectFit
                    width: 80; height: 80
                    asynchronous: true
                    sourceSize: Qt.size(160, 160)
                }
                Text {
                    text: "NOW SERVING"
                    font.family: DisplayState.fontFamily
                    font.pixelSize: Math.max(display_root.height * 0.04, 16)
                    font.letterSpacing: 8
                    font.weight: Font.Light
                    color: DisplayState.textColor
                    opacity: 0.6
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: DisplayState.currentNumber
                    font.family: DisplayState.fontFamily
                    font.pixelSize: DisplayState.fontSize * (display_root.height / 480)
                    font.weight: Font.Bold
                    color: DisplayState.accentColor
                    Layout.alignment: Qt.AlignHCenter
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
                Text {
                    text: DisplayState.facilityName
                    font.family: DisplayState.fontFamily
                    font.pixelSize: Math.max(display_root.height * 0.025, 11)
                    color: DisplayState.textColor
                    opacity: 0.45
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(display_root.height * 0.1, 44)
                color: DisplayState.bannerBg
                Behavior on color { ColorAnimation { duration: 400 } }
                Text {
                    anchors.centerIn: parent
                    text: DisplayState.bannerText
                    font.family: DisplayState.fontFamily
                    font.pixelSize: Math.max(display_root.height * 0.028, 12)
                    color: DisplayState.bannerText_c
                    elide: Text.ElideRight
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ── SPLIT layout ──────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: DisplayState.layoutType === "Split"

            Row {
                anchors.fill: parent

                Rectangle {
                    width: parent.width * 0.55; height: parent.height
                    color: DisplayState.headerColor
                    Behavior on color { ColorAnimation { duration: 400 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: DisplayState.logoSource
                            width: 72; height: 72
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(144, 144)
                        }
                        Text {
                            text: "NOW SERVING"
                            font.family: DisplayState.fontFamily
                            font.pixelSize: Math.max(display_root.height * 0.035, 14)
                            font.letterSpacing: 5
                            font.weight: Font.Light
                            color: "#FFFFFF"; opacity: 0.75
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: DisplayState.currentNumber
                            font.family: DisplayState.fontFamily
                            font.pixelSize: DisplayState.fontSize * (display_root.height / 480) * 1.1
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                Rectangle {
                    width: parent.width * 0.45; height: parent.height
                    color: DisplayState.backgroundColor
                    ColumnLayout {
                        anchors { fill: parent; margins: 24 }
                        spacing: 0
                        Text {
                            text: "NEXT UP"
                            font.family: DisplayState.fontFamily
                            font.pixelSize: Math.max(display_root.height * 0.03, 12)
                            font.letterSpacing: 4; font.weight: Font.Light
                            color: DisplayState.textColor; opacity: 0.55
                            Layout.bottomMargin: 16
                        }
                        Repeater {
                            model: ["043", "044", "045", "046"]
                            delegate: Item {
                                Layout.fillWidth: true; height: 56
                                Rectangle {
                                    anchors { fill: parent; topMargin: 3; bottomMargin: 3 }
                                    radius: 8
                                    color: FluTheme.dark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.04)
                                    Text {
                                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                                        text: modelData
                                        font.family: DisplayState.fontFamily
                                        font.pixelSize: Math.max(display_root.height * 0.04, 18)
                                        font.weight: Font.Medium
                                        color: DisplayState.textColor
                                        opacity: 1.0 - index * 0.18
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle {
                            Layout.fillWidth: true
                            height: Math.max(display_root.height * 0.09, 40)
                            radius: 8; color: DisplayState.bannerBg
                            Text {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 14 }
                                text: DisplayState.bannerText
                                font.family: DisplayState.fontFamily
                                font.pixelSize: Math.max(display_root.height * 0.024, 11)
                                color: DisplayState.bannerText_c
                                wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 2
                            }
                        }
                    }
                }
            }
        }

        // ── BOOT QR OVERLAY ───────────────────────────────────────────────
        // Fixed 200x260 card, bottom-right. Opacity starts at 1, fades out
        // after 3 min. Component.onCompleted fires on every navigation visit.
        Rectangle {
            id: qr_overlay
            anchors {
                right:        parent.right
                bottom:       parent.bottom
                rightMargin:  24
                bottomMargin: 24
            }
            width:  200
            height: 260
            radius: 14
            color:  Qt.rgba(0, 0, 0, 0.75)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.20)
            z: 20
            opacity: 1

            SequentialAnimation on opacity {
                id: qr_anim
                running: false
                NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.OutCubic }
                PauseAnimation  { duration: 180000 }
                NumberAnimation { to: 0.0; duration: 800; easing.type: Easing.InCubic }
            }

            Component.onCompleted: qr_anim.restart()

            Column {
                anchors {
                    top:              parent.top
                    left:             parent.left
                    right:            parent.right
                    topMargin:        14
                    leftMargin:       14
                    rightMargin:      14
                }
                spacing: 10

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Scan to customise"
                    font.pixelSize: 12
                    font.family: DisplayState.fontFamily
                    color: "#FFFFFF"
                    opacity: 0.90
                }

                FluQRCode {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size:    160
                    text:    NetworkHelper.adminUrl
                    color:   "#000000"
                    bgColor: "#FFFFFF"
                    margins: 0
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: NetworkHelper.adminUrl
                    font.pixelSize: 9
                    font.family: DisplayState.fontFamily
                    color: "#FFFFFF"
                    opacity: 0.60
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
