import QtQuick

// Numeric setting with -/+ controls, on Omarchy's control tokens.
Item {
    id: root

    property string label: ""
    property string description: ""
    property int value: 0
    property string suffix: ""
    property int minimum: 0
    property int maximum: 100
    property int step: 1

    // Assigned a function by the caller; called with the new value.
    property var onChanged: null

    readonly property bool hot: hover.hovered

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.controlHeight + Theme.spacingXl, text.implicitHeight + Theme.spacingXl)

    function apply(next) {
        const clamped = Math.max(root.minimum, Math.min(root.maximum, next));
        if (clamped !== root.value && root.onChanged) root.onChanged(clamped);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.hot ? Theme.fill("hover-cursor") : "transparent"

        Behavior on color {
            enabled: Config.animate
            ColorAnimation { duration: 100 }
        }
    }

    HoverHandler { id: hover }

    Column {
        id: text

        anchors.left: parent.left
        anchors.leftMargin: Theme.rowPaddingX
        anchors.right: controls.left
        anchors.rightMargin: Theme.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXs

        Text {
            text: root.label
            color: Theme.foreground
            font.family: Theme.menuFontFamily
            font.pixelSize: Theme.fontSubtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            visible: root.description !== ""
            text: root.description
            color: Qt.darker(Theme.foreground, 1.5)
            font.family: Theme.menuFontFamily
            font.pixelSize: Theme.fontCaption
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: Theme.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingMd

        SettingsButton {
            text: "−"
            enabled: root.value > root.minimum
            onClicked: root.apply(root.value - root.step)
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.space(58)
            horizontalAlignment: Text.AlignHCenter
            text: root.value + root.suffix
            color: Qt.darker(Theme.foreground, 1.4)
            font.family: Theme.menuFontFamily
            font.pixelSize: Theme.fontBody
        }

        SettingsButton {
            text: "+"
            enabled: root.value < root.maximum
            onClicked: root.apply(root.value + root.step)
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
