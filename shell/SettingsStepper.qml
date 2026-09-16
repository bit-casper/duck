import QtQuick

// Numeric setting with -/+ controls. Simpler to theme than a slider and
// precise enough for pixel and millisecond values.
Item {
    id: root

    property string label: ""
    property int value: 0
    property string suffix: ""
    property int minimum: 0
    property int maximum: 100
    property int step: 1

    // Assigned a function by the caller; called with the new value.
    property var onChanged: null

    width: parent ? parent.width : 0
    height: 40

    function apply(next) {
        const clamped = Math.max(root.minimum, Math.min(root.maximum, next));
        if (clamped !== root.value && root.onChanged) root.onChanged(clamped);
    }

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.foreground
        font.pixelSize: 13
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        SettingsButton {
            text: "−"
            enabled: root.value > root.minimum
            onClicked: root.apply(root.value - root.step)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            horizontalAlignment: Text.AlignHCenter
            text: root.value + root.suffix
            color: Theme.muted
            font.pixelSize: 12
        }

        SettingsButton {
            text: "+"
            enabled: root.value < root.maximum
            onClicked: root.apply(root.value + root.step)
        }
    }
}
