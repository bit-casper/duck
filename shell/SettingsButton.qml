import QtQuick

// Compact button for the per-app row controls, styled from Omarchy's control
// tokens so it matches the buttons in its panels.
Rectangle {
    id: root

    property string text: ""
    property bool danger: false
    property bool enabled: true

    signal clicked()

    readonly property string state: !root.enabled ? "normal" : (area.containsMouse ? "hover-cursor" : "normal")

    width: Theme.controlHeight
    height: Theme.controlHeight
    radius: Theme.cornerRadius

    color: area.containsMouse && root.enabled ? Theme.fill("hover-cursor") : Theme.fill("normal")
    border.width: Theme.borderWidthFor(root.state)
    border.color: root.danger && area.containsMouse ? Theme.colorToken("#ED5B5A", Theme.accent) : Theme.border(root.state)
    opacity: root.enabled ? 1 : 0.35

    Behavior on color {
        enabled: Config.animate
        ColorAnimation { duration: 100 }
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.danger && area.containsMouse ? Theme.colorToken("#ED5B5A", Theme.accent) : Theme.foreground
        font.family: Theme.menuFontFamily
        font.pixelSize: Theme.fontBody
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
