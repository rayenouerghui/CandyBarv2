import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import FluentUI 1.0

FluPage {
    title: "Message Log"

    ListModel { id: logModel }
    property int totalCount: 0

    Connections {
        target: MqttClient
        function onMessageReceived(topic, payload) {
            var ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
            logModel.insert(0, { timestamp: ts, topic: topic, payload: payload })
            totalCount++
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 24; topMargin: 16 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            FluText { text: "Message Log"; font: FluTextStyle.Subtitle }
            FluBadge { count: totalCount; visible: totalCount > 0; anchors.verticalCenter: parent.verticalCenter }
            Item { Layout.fillWidth: true }
            FluText {
                text: logModel.count + " entries"
                color: FluTheme.fontSecondaryColor
                font: FluTextStyle.Caption
                anchors.verticalCenter: parent.verticalCenter
            }
            FluButton {
                text: "Clear Log"
                enabled: logModel.count > 0
                onClicked: { logModel.clear(); totalCount = 0 }
            }
        }

        FluFrame {
            Layout.fillWidth: true
            radius: 6
            padding: 0
            Rectangle { anchors.fill: parent; radius: 6; color: FluTheme.itemHoverColor }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                height: 34
                spacing: 0
                FluText { text: "Timestamp"; font: FluTextStyle.BodyStrong; Layout.preferredWidth: 160 }
                FluText { text: "Topic";     font: FluTextStyle.BodyStrong; Layout.preferredWidth: 180 }
                FluText { text: "Payload";   font: FluTextStyle.BodyStrong; Layout.fillWidth: true }
            }
        }

        FluFrame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            padding: 0
            clip: true

            FluText {
                anchors.centerIn: parent
                text: "No messages logged yet."
                horizontalAlignment: Text.AlignHCenter
                color: FluTheme.fontTertiaryColor
                visible: logModel.count === 0
            }

            ListView {
                id: log_list
                anchors { fill: parent; margins: 1 }
                model: logModel
                clip: true
                spacing: 0
                ScrollBar.vertical: FluScrollBar {}

                delegate: Item {
                    width: log_list.width
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        color: index % 2 === 0 ? FluTheme.itemNormalColor : FluTheme.itemHoverColor
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 0

                        FluText {
                            text: model.timestamp
                            font: FluTextStyle.Caption
                            color: FluTheme.fontSecondaryColor
                            Layout.preferredWidth: 160
                        }

                        Rectangle {
                            height: 18
                            width: Math.min(chip_lbl.implicitWidth + 10, 170)
                            radius: 4
                            Layout.preferredWidth: 180
                            color: Qt.rgba(FluTheme.primaryColor.r, FluTheme.primaryColor.g, FluTheme.primaryColor.b, 0.12)
                            FluText {
                                id: chip_lbl
                                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                                text: model.topic
                                color: FluTheme.primaryColor
                                font: FluTextStyle.Caption
                                elide: Text.ElideRight
                                width: parent.width - 10
                            }
                        }

                        FluText {
                            text: model.payload
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font: FluTextStyle.Body
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: FluTheme.dividerColor; opacity: 0.3
                    }
                }
            }
        }
    }
}
