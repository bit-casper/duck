import QtQuick
import Quickshell
import Quickshell.Widgets

// One app in the dock. Purely presentational — the dock owns selection, drag
// state and click handling so that reordering never destroys a live delegate.
Item {
    id: root

    required property var item
    property int iconSize: 44
    property bool selected: false
    property bool hovered: false
    property bool dragging: false

    implicitWidth: iconSize + 12
    implicitHeight: iconSize + 12

    readonly property bool active: selected || hovered

    // Hover/selection backplate.
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.foreground
        opacity: root.active ? (root.selected ? 0.16 : 0.09) : 0

        Behavior on opacity {
            enabled: Config.animate
            NumberAnimation { duration: 110 }
        }
    }

    // Keyboard selection gets a visible outline, since the fill alone is subtle.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
        opacity: root.selected ? 0.8 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: Config.animate
            NumberAnimation { duration: 110 }
        }
    }

    IconImage {
        id: icon

        anchors.centerIn: parent
        implicitSize: root.iconSize
        asynchronous: true
        // Already resolved to a usable URL by Icons.source() in Apps.buildItems.
        source: root.item.icon ? root.item.icon : Icons.fallback

        opacity: root.dragging ? 0.25 : 1
        scale: root.active && !root.dragging ? 1.08 : 1

        Behavior on scale {
            enabled: Config.animate
            NumberAnimation { duration: 130; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            enabled: Config.animate
            NumberAnimation { duration: 110 }
        }
    }

    // A pinned app whose .desktop file could not be resolved.
    Rectangle {
        anchors.centerIn: parent
        width: root.iconSize * 0.5
        height: width
        visible: root.item.missing === true
        color: "transparent"
        border.width: 1
        border.color: Theme.muted

        Text {
            anchors.centerIn: parent
            text: "?"
            color: Theme.muted
            font.pixelSize: parent.height * 0.7
        }
    }

    // Running indicator.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        spacing: 3
        visible: root.item.running && !root.dragging

        Repeater {
            // Up to three dots, so two windows read differently from one.
            model: Math.min(root.item.windows ? root.item.windows.length : 0, 3)

            Rectangle {
                width: 3
                height: 3
                radius: 1.5
                color: Theme.accent
            }
        }
    }
}
