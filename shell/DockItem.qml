import QtQuick
import Quickshell
import Quickshell.Widgets

// One app in the dock. Purely presentational — the dock owns selection, drag
// state and click handling so that reordering never destroys a live delegate.
//
// Hover and selection use Omarchy's control-state tokens, so the highlight is
// the same treatment its own panels and menus use.
Item {
    id: root

    required property var item
    property int iconSize: 24
    property bool selected: false
    property bool hovered: false
    property bool dragging: false

    implicitWidth: iconSize + Theme.spacingXxl
    implicitHeight: iconSize + Theme.spacingXxl

    readonly property string state: selected ? "selected" : (hovered ? "hover-cursor" : "normal")
    readonly property bool active: selected || hovered

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.active ? Theme.fill(root.state) : "transparent"
        border.width: root.active ? Theme.borderWidthFor(root.state) : 0
        border.color: Theme.border(root.state)

        Behavior on color {
            enabled: Config.animate
            ColorAnimation { duration: 110 }
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
        radius: Theme.cornerRadius

        Text {
            anchors.centerIn: parent
            text: "?"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: parent.height * 0.7
        }
    }

    // Running indicator: one dot per window, up to three.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        spacing: Theme.spacingXs
        visible: root.item.running && !root.dragging

        Repeater {
            model: Math.min(root.item.windows ? root.item.windows.length : 0, 3)

            Rectangle {
                width: 3
                height: 3
                radius: Theme.cornerRadius > 0 ? 1.5 : 0
                color: Theme.accent
            }
        }
    }
}
