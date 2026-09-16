import QtQuick

// Labeled toggle row, modelled on Omarchy's Ui/Toggle + Ui/ToggleSwitch.
//
// Shape follows the theme: the track and knob are square when Hyprland corners
// are square, a pill when they are rounded — the same rule Omarchy's own
// switches use, which is why the audio panel reads as square on this setup.
Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false

    signal toggled()

    readonly property bool rounded: Theme.cornerRadius > 0
    readonly property bool hot: mouse.containsMouse

    property int trackHeight: Math.max(18, Math.round(Theme.controlHeight * 0.55))
    readonly property int trackWidth: Math.round(trackHeight * 1.9)
    readonly property int knobSize: Math.max(6, Math.round(trackHeight * 0.72))
    readonly property int knobInset: Math.max(1, Math.round((trackHeight - knobSize) / 2))

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.controlHeight + Theme.spacingXl, text.implicitHeight + Theme.spacingXl)

    // Row backplate, lit on hover exactly like an Omarchy control row.
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.hot ? Theme.fill("hover-cursor") : "transparent"

        Behavior on color {
            enabled: Config.animate
            ColorAnimation { duration: 100 }
        }
    }

    Column {
        id: text

        anchors.left: parent.left
        anchors.leftMargin: Theme.rowPaddingX
        anchors.right: track.left
        anchors.rightMargin: Theme.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXs

        Text {
            textFormat: Text.PlainText
            text: root.label
            color: Theme.foreground
            font.family: Theme.menuFontFamily
            font.pixelSize: Theme.fontSubtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            textFormat: Text.PlainText
            visible: root.description !== ""
            text: root.description
            color: Qt.darker(Theme.foreground, 1.5)
            font.family: Theme.menuFontFamily
            font.pixelSize: Theme.fontCaption
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: Theme.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        width: root.trackWidth
        height: root.trackHeight
        radius: root.rounded ? height / 2 : 0

        color: root.checked ? Theme.fill("selected") : Theme.fill("normal")
        border.width: root.checked ? Theme.borderWidthFor("selected") : Theme.borderWidthFor("normal")
        border.color: root.checked ? Theme.border("selected") : Theme.border("normal")

        Behavior on color {
            enabled: Config.animate
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            width: root.knobSize
            height: root.knobSize
            radius: root.rounded ? height / 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - root.knobInset : root.knobInset
            color: root.checked ? Theme.accent : Qt.darker(Theme.foreground, 1.25)

            Behavior on x {
                enabled: Config.animate
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                enabled: Config.animate
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
