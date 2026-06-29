import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import FluentUI 1.0

FluScrollablePage {
    title: "Order Status Display"

    ListModel { id: orderModel }
    property var orderIndex: ({})

    Connections {
        target: MqttClient
        function onOrderReceived(orderJson) {
            var o = JSON.parse(orderJson)
            if (orderIndex.hasOwnProperty(o.order_id)) {
                var idx = orderIndex[o.order_id]
                orderModel.set(idx, {
                    order_id:  o.order_id,
                    table:     o.table,
                    items:     o.items.join(", "),
                    status:    o.status,
                    timestamp: o.timestamp
                })
            } else {
                orderModel.insert(0, {
                    order_id:  o.order_id,
                    table:     o.table,
                    items:     o.items.join(", "),
                    status:    o.status,
                    timestamp: o.timestamp
                })
                var newIndex = {}
                newIndex[o.order_id] = 0
                for (var key in orderIndex) {
                    newIndex[key] = orderIndex[key] + 1
                }
                orderIndex = newIndex
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        FluFrame {
            Layout.preferredWidth: 160
            Layout.preferredHeight: 80
            radius: 8
            padding: 14
            ColumnLayout {
                spacing: 4
                anchors.fill: parent
                FluText { text: "Total Orders"; font: FluTextStyle.Caption; color: FluTheme.fontSecondaryColor }
                FluText {
                    text: orderModel.count.toString()
                    font: FluTextStyle.TitleLarge
                    color: FluTheme.primaryColor
                }
            }
        }

        FluFrame {
            Layout.preferredWidth: 160
            Layout.preferredHeight: 80
            radius: 8
            padding: 14
            ColumnLayout {
                spacing: 4
                anchors.fill: parent
                FluText { text: "Pending"; font: FluTextStyle.Caption; color: FluTheme.fontSecondaryColor }
                FluText {
                    text: {
                        var c = 0
                        for (var i = 0; i < orderModel.count; i++)
                            if (orderModel.get(i).status === "Pending") c++
                        return c.toString()
                    }
                    font: FluTextStyle.TitleLarge
                    color: "#faad14"
                }
            }
        }

        FluFrame {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 80
            radius: 8
            padding: 14
            ColumnLayout {
                spacing: 4
                anchors.fill: parent
                FluText { text: "Broker"; font: FluTextStyle.Caption; color: FluTheme.fontSecondaryColor }
                RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: MqttClient.connected ? "#52c41a" : "#ff4d4f"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    FluText {
                        text: MqttClient.connected ? MqttClient.broker : "Not connected"
                        font: FluTextStyle.BodyStrong
                        color: MqttClient.connected ? "#52c41a" : "#ff4d4f"
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        FluButton {
            text: "Clear All"
            enabled: orderModel.count > 0
            onClicked: { orderModel.clear(); orderIndex = {} }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        visible: orderModel.count === 0
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            FluIcon {
                iconSource: FluentIcons.ViewAll
                iconSize: 40
                color: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignHCenter
            }
            FluText {
                text: "No orders received yet"
                font: FluTextStyle.Subtitle
                color: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignHCenter
            }
            FluText {
                text: "Run publisher.py to start receiving orders"
                color: FluTheme.fontTertiaryColor
                font: FluTextStyle.Caption
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    GridView {
        id: order_grid
        Layout.fillWidth: true
        Layout.preferredHeight: Math.ceil(orderModel.count / Math.max(1, Math.floor(width / 240))) * 190
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 240)))
        cellHeight: 190
        model: orderModel
        interactive: false
        visible: orderModel.count > 0

        delegate: Item {
            width: order_grid.cellWidth
            height: order_grid.cellHeight
            FluFrame {
                anchors { fill: parent; margins: 8 }
                radius: 8
                padding: 0
                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        FluText { text: model.order_id; font: FluTextStyle.BodyStrong }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            height: 20
                            width: tbl_lbl.implicitWidth + 12
                            radius: 4
                            color: Qt.rgba(FluTheme.primaryColor.r, FluTheme.primaryColor.g, FluTheme.primaryColor.b, 0.15)
                            FluText {
                                id: tbl_lbl
                                anchors.centerIn: parent
                                text: model.table
                                font: FluTextStyle.Caption
                                color: FluTheme.primaryColor
                            }
                        }
                    }
                    FluDivider {}
                    FluText {
                        text: model.items
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font: FluTextStyle.Body
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            height: 22
                            width: status_lbl.implicitWidth + 14
                            radius: 11
                            color: {
                                switch (model.status) {
                                    case "Pending":   return "#faad14"
                                    case "Preparing": return "#1890ff"
                                    case "Ready":     return "#52c41a"
                                    case "Delivered": return "#bfbfbf"
                                    default:          return "#faad14"
                                }
                            }
                            FluText {
                                id: status_lbl
                                anchors.centerIn: parent
                                text: model.status
                                font: FluTextStyle.Caption
                                color: "#ffffff"
                            }
                        }
                        Item { Layout.fillWidth: true }
                        FluText {
                            text: model.timestamp
                            font: FluTextStyle.Caption
                            color: FluTheme.fontTertiaryColor
                        }
                    }
                }
            }
        }
    }
}
