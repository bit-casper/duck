import QtQuick

// Section heading with a hairline rule.
Column {
    id: root

    property string title: ""

    width: parent ? parent.width : 0
    topPadding: 16
    bottomPadding: 6
    spacing: 6

    Text {
        text: root.title
        color: Theme.accent
        font.pixelSize: 12
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    Rectangle {
        width: root.width
        height: 1
        color: Theme.foreground
        opacity: 0.12
    }
}
