import QtQuick

// Compact square button used for the per-app row controls.
Rectangle {
    id: root

    property string text: ""
    property bool danger: false
    property bool enabled: true

    signal clicked()

    width: 26
    height: 26
    color: area.containsMouse && root.enabled
        ? (root.danger ? Qt.rgba(1, 0.3, 0.3, 0.18) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22))
        : "transparent"
    border.width: 1
    border.color: root.enabled ? Theme.muted : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.3)
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.danger && area.containsMouse ? "#ff6b6b" : Theme.foreground
        font.pixelSize: 12
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
