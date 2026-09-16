import QtQuick

// Section heading with a hairline rule, using Omarchy's type and spacing scale.
Column {
    id: root

    property string title: ""

    width: parent ? parent.width : 0
    topPadding: Theme.spacingHuge
    bottomPadding: Theme.spacingMd
    spacing: Theme.spacingMd

    Text {
        text: root.title
        color: Theme.accent
        font.family: Theme.menuFontFamily
        font.pixelSize: Theme.fontCaption
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
        x: Theme.rowPaddingX
    }

    Rectangle {
        width: root.width
        height: 1
        color: Theme.foreground
        opacity: 0.12
    }
}
