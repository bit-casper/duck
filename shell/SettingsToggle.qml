import QtQuick

// Label + description on the left, a pill switch on the right.
Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false

    signal toggled()

    width: parent ? parent.width : 0
    height: 48

    Column {
        anchors.left: parent.left
        anchors.right: pill.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.label
            color: Theme.foreground
            font.pixelSize: 13
        }
        Text {
            text: root.description
            visible: root.description !== ""
            color: Theme.muted
            font.pixelSize: 11
            width: parent.width
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: pill

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: 22
        radius: 11
        color: root.checked ? Theme.accent : "transparent"
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.muted

        Behavior on color {
            NumberAnimation { duration: 120 }
        }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.background : Theme.muted

            Behavior on x {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
