import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import FluentUI 1.0

FluScrollablePage {
    title: "MQTT Demo"

    // ── state ─────────────────────────────────────────────────────────────
    ListModel { id: receivedModel }
    property int receivedCount: 0

    Connections {
        target: MqttClient

        function onMessageReceived(topic, payload) {
            var ts = Qt.formatTime(new Date(), "hh:mm:ss")
            if (receivedModel.count >= 50)
                receivedModel.remove(receivedModel.count - 1)
            receivedModel.insert(0, { timestamp: ts, topic: topic, payload: payload })
            receivedCount++
        }

        function onConnectionStatusChanged(status) {
            if (MqttClient.connected)
                showSuccess("Connected to EMQX  " + MqttClient.broker)
            else
                showWarning("Disconnected")
        }
    }

    // ── header: broker status ─────────────────────────────────────────────
    FluFrame {
        Layout.fillWidth: true
        radius: 8
        padding: 16

        RowLayout {
            anchors.fill: parent
            spacing: 24

            // dot + label
            RowLayout {
                spacing: 8
                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: MqttClient.connected ? "#52c41a" : "#ff4d4f"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                FluText {
                    text: MqttClient.connected ? "Connected" : "Disconnected"
                    font: FluTextStyle.BodyStrong
                    color: MqttClient.connected ? "#52c41a" : "#ff4d4f"
                }
            }

            FluDivider { orientation: Qt.Vertical; implicitHeight: 36 }

            ColumnLayout {
                spacing: 2
                FluText { text: "Broker"; color: FluTheme.fontSecondaryColor; font: FluTextStyle.Caption }
                FluText { text: MqttClient.broker; font: FluTextStyle.Body }
            }

            FluDivider { orientation: Qt.Vertical; implicitHeight: 36 }

            ColumnLayout {
                spacing: 2
                FluText { text: "Topic"; color: FluTheme.fontSecondaryColor; font: FluTextStyle.Caption }
                FluText { text: MqttClient.topic; font: FluTextStyle.Body }
            }

            Item { Layout.fillWidth: true }

            FluFilledButton {
                text: MqttClient.connected ? "Disconnect" : "Connect to EMQX"
                onClicked: MqttClient.connected ? MqttClient.disconnect_broker() : MqttClient.connect_broker()
            }
        }
    }

    // ── two-column layout ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        spacing: 16

        // ── LEFT: Publisher ───────────────────────────────────────────────
        FluFrame {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            radius: 8
            padding: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    spacing: 8
                    FluIcon { iconSource: FluentIcons.Send; iconSize: 18; color: FluTheme.primaryColor }
                    FluText { text: "Publisher"; font: FluTextStyle.Subtitle }
                }

                FluText {
                    text: "Type a message and click Send (or press Enter).\nThe subscriber panel on the right will receive it instantly."
                    color: FluTheme.fontSecondaryColor
                    font: FluTextStyle.Caption
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluDivider {}

                FluText { text: "Message"; font: FluTextStyle.BodyStrong }

                FluTextBox {
                    id: msg_input
                    Layout.fillWidth: true
                    placeholderText: "e.g.  Hello from Publisher!"
                    enabled: MqttClient.connected
                    Keys.onReturnPressed: sendMessage()
                }

                FluFilledButton {
                    text: "Send"
                    Layout.fillWidth: true
                    enabled: MqttClient.connected && msg_input.text.trim().length > 0
                    onClicked: sendMessage()
                }

                // quick presets
                FluText { text: "Quick presets"; font: FluTextStyle.Caption; color: FluTheme.fontSecondaryColor }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["Hello MQTT!", "EMQX is running ✓", "PySide6 + QML", "Test message 123", "It works!"]
                        FluButton {
                            text: modelData
                            enabled: MqttClient.connected
                            onClicked: { msg_input.text = modelData; sendMessage() }
                        }
                    }
                }

                Item { Layout.preferredHeight: 8 }
            }
        }

        // ── RIGHT: Subscriber ─────────────────────────────────────────────
        FluFrame {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            radius: 8
            padding: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    spacing: 8
                    FluIcon { iconSource: FluentIcons.Download; iconSize: 18; color: "#52c41a" }
                    FluText { text: "Subscriber"; font: FluTextStyle.Subtitle }
                    Item { Layout.fillWidth: true }
                    FluBadge { count: receivedCount; visible: receivedCount > 0; anchors.verticalCenter: parent.verticalCenter }
                    FluText {
                        text: receivedCount + " received"
                        font: FluTextStyle.Caption
                        color: FluTheme.fontSecondaryColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    FluButton {
                        text: "Clear"
                        enabled: receivedModel.count > 0
                        onClicked: { receivedModel.clear(); receivedCount = 0 }
                    }
                }

                FluText {
                    text: "Messages arriving on  " + MqttClient.topic
                    color: FluTheme.fontSecondaryColor
                    font: FluTextStyle.Caption
                }

                FluDivider {}

                // empty state
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    visible: receivedModel.count === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        FluIcon {
                            iconSource: FluentIcons.Streaming
                            iconSize: 36
                            color: FluTheme.fontTertiaryColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            text: "Waiting for messages…"
                            color: FluTheme.fontTertiaryColor
                            font: FluTextStyle.Body
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            text: "Send something from the Publisher panel\nor run:  python mqtt_demo/publisher.py"
                            color: FluTheme.fontTertiaryColor
                            font: FluTextStyle.Caption
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // message list
                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 280
                    radius: 6
                    padding: 0
                    clip: true
                    visible: receivedModel.count > 0

                    ListView {
                        id: sub_list
                        anchors { fill: parent; margins: 1 }
                        model: receivedModel
                        clip: true
                        spacing: 0
                        ScrollBar.vertical: FluScrollBar {}

                        delegate: Item {
                            width: sub_list.width
                            height: 52

                            Rectangle {
                                anchors.fill: parent
                                color: index % 2 === 0 ? FluTheme.itemNormalColor : FluTheme.itemHoverColor
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                spacing: 10

                                FluText {
                                    text: model.timestamp
                                    color: FluTheme.fontSecondaryColor
                                    font: FluTextStyle.Caption
                                    Layout.preferredWidth: 58
                                }

                                Rectangle {
                                    height: 20; width: 8; radius: 4
                                    color: "#52c41a"
                                    anchors.verticalCenter: parent.verticalCenter
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
    }

    // ── how-to footer ─────────────────────────────────────────────────────
    FluFrame {
        Layout.fillWidth: true
        Layout.topMargin: 4
        radius: 8
        padding: 14

        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            FluText { text: "How to run the standalone terminals"; font: FluTextStyle.BodyStrong }
            FluText {
                text: "Terminal 1 (Publisher):   python mqtt_demo/publisher.py\n" +
                      "Terminal 2 (Subscriber):  python mqtt_demo/subscriber.py\n\n" +
                      "Both the subscriber terminal and this app will receive every message you type in the publisher."
                font: FluTextStyle.Caption
                color: FluTheme.fontSecondaryColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    function sendMessage() {
        var txt = msg_input.text.trim()
        if (txt.length === 0 || !MqttClient.connected) return
        MqttClient.publish(txt)
        showSuccess("Sent: " + txt)
        msg_input.text = ""
        msg_input.forceActiveFocus()
    }
}
