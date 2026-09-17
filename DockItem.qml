import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons

// One app in the dock. Purely presentational — the dock owns selection, drag
// state and click handling so that reordering never destroys a live delegate.
//
// Hover and selection use Omarchy's control-state tokens, so the highlight is
// the same treatment its own panels and menus use.
Item {
    id: root

    required property var item
    // Only needed for the `animate` setting; the dock passes its own down.
    required property var config
    property int iconSize: 24
    property bool selected: false
    property bool hovered: false
    property bool dragging: false

    implicitWidth: iconSize + Style.spacing.xxl
    implicitHeight: iconSize + Style.spacing.xxl

    readonly property bool active: selected || hovered

    // Omarchy's control states: a selected icon reads as "selected", a hovered
    // one as the shared hover/keyboard-cursor treatment.
    readonly property color stateFill: root.selected ? Style.selectedFill : Style.hoverFill
    readonly property color stateBorder: root.selected ? Style.selectedBorderColor : Style.hoverBorderColor
    readonly property int stateBorderWidth: root.selected ? Style.selectedBorderWidth : Style.hoverBorderWidth

    Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: root.active ? root.stateFill : "transparent"
        border.width: root.active ? root.stateBorderWidth : 0
        border.color: root.stateBorder

        Behavior on color {
            enabled: root.config.animate
            ColorAnimation { duration: 110 }
        }
    }

    IconImage {
        id: icon

        anchors.centerIn: parent
        implicitSize: root.iconSize
        asynchronous: true
        // Already resolved to a usable URL by DuckIcons.source() in buildItems,
        // which substitutes the generic fallback when an app has no icon.
        source: root.item.icon ? root.item.icon : ""

        opacity: root.dragging ? 0.25 : 1
        scale: root.active && !root.dragging ? 1.08 : 1

        Behavior on scale {
            enabled: root.config.animate
            NumberAnimation { duration: 130; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            enabled: root.config.animate
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
        border.color: Color.muted
        radius: Style.cornerRadius

        Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "?"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: parent.height * 0.7
        }
    }

    // Running indicator: one dot per window, up to three.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        spacing: Style.spacing.xs
        visible: root.item.running && !root.dragging

        Repeater {
            model: Math.min(root.item.windows ? root.item.windows.length : 0, 3)

            Rectangle {
                width: 3
                height: 3
                radius: Style.cornerRadius > 0 ? 1.5 : 0
                color: Color.accent
            }
        }
    }
}
