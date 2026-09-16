import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// Duck's settings.
//
// Built from Omarchy's own Ui kit — Toggle, NumberField, Button — rather than
// lookalikes, so it inherits their behaviour and restyles with the rest of the
// shell when a theme changes.
//
// No border is drawn here: this is an ordinary Hyprland window and the
// compositor already draws the themed border around it.
FloatingWindow {
    id: root

    required property var duck

    readonly property var config: duck.config
    readonly property var apps: duck.apps

    implicitWidth: 520
    implicitHeight: 720
    title: "Duck Settings"
    color: Color.background

    Rectangle {
        anchors.fill: parent
        color: Color.background

        Flickable {
            id: scroll

            anchors.fill: parent
            anchors.margins: Style.spacing.panelPadding
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: scroll.width
                spacing: Style.spacing.xs

                Text {
                    text: "Duck"
                    textFormat: Text.PlainText
                    color: Color.foreground
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                    bottomPadding: Style.spacing.lg
                }

                // --- appearance ---------------------------------------------

                PanelSectionHeader { text: "Appearance" }

                Toggle {
                    width: content.width
                    label: "Bordered"
                    description: checked ? "Square themed border and solid background, like an ordinary window"
                                         : "No border, with a gradient fading up from the screen edge"
                    checked: root.config.bordered
                    onClicked: root.config.set("bordered", !root.config.bordered)
                }

                Toggle {
                    width: content.width
                    label: "Animations"
                    description: "Slide and hover transitions"
                    checked: root.config.animate
                    onClicked: root.config.set("animate", !root.config.animate)
                }

                // --- behavior -----------------------------------------------

                PanelSectionHeader { text: "Behavior" }

                Toggle {
                    width: content.width
                    label: "Push windows up"
                    description: checked ? "Windows resize to make room for the dock"
                                         : "Dock overlays whatever is on screen"
                    checked: root.config.pushWindows
                    onClicked: root.config.set("pushWindows", !root.config.pushWindows)
                }

                Toggle {
                    width: content.width
                    label: "Show running apps"
                    description: checked ? "Running apps you have not pinned appear after the pinned ones"
                                         : "Only pinned apps are shown"
                    checked: root.config.showRunning
                    onClicked: root.config.set("showRunning", !root.config.showRunning)
                }

                Toggle {
                    width: content.width
                    label: "Reveal on bottom edge"
                    description: checked ? "Dock slides up when the mouse reaches the edge"
                                         : "Keyboard only (Super+Ctrl+Down)"
                    checked: root.config.edgeReveal
                    onClicked: root.config.set("edgeReveal", !root.config.edgeReveal)
                }

                // Side by side: the two delays are a pair, and stacking two
                // narrow fields down the left edge left the row half empty.
                Item {
                    width: content.width
                    implicitHeight: delays.implicitHeight + Style.spacing.md

                    Row {
                        id: delays

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.spacing.controlGap

                        readonly property int fieldWidth: Math.floor((width - spacing) / 2)

                        NumberField {
                            label: "Reveal delay (ms)"
                            fieldWidth: delays.fieldWidth
                            value: root.config.revealDelay
                            from: 0
                            to: 1000
                            stepSize: 30
                            enabled: root.config.edgeReveal
                            opacity: root.config.edgeReveal ? 1 : 0.4
                            onModified: function (next) { root.config.set("revealDelay", next); }
                        }

                        NumberField {
                            label: "Hide delay (ms)"
                            fieldWidth: delays.fieldWidth
                            value: root.config.hideDelay
                            from: 0
                            to: 2000
                            stepSize: 50
                            onModified: function (next) { root.config.set("hideDelay", next); }
                        }
                    }
                }

                // --- pinned apps --------------------------------------------

                Item { width: 1; height: Style.spacing.lg }

                PanelSectionHeader { text: "Pinned apps" }

                Text {
                    visible: root.config.apps.length === 0
                    text: "Nothing pinned yet — try  duck add ghostty"
                    textFormat: Text.PlainText
                    color: Qt.darker(Color.foreground, 1.5)
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                    topPadding: Style.spacing.sm
                }

                Repeater {
                    model: root.config.apps

                    Item {
                        id: appRow

                        required property int index
                        required property string modelData

                        readonly property var entry: root.apps.entryFor(modelData)

                        width: content.width
                        implicitHeight: Style.spacing.controlHeight + Style.spacing.xl

                        Rectangle {
                            anchors.fill: parent
                            radius: Style.cornerRadius
                            color: rowHover.hovered ? Style.hoverFill : "transparent"

                            Behavior on color {
                                enabled: root.config.animate
                                ColorAnimation { duration: 100 }
                            }
                        }

                        HoverHandler { id: rowHover }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Style.spacing.rowPaddingX
                            anchors.right: appControls.left
                            anchors.rightMargin: Style.spacing.rowPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.spacing.lg

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Style.font.heading + Style.spacing.lg
                                source: appRow.entry ? root.duck.icons.source(appRow.entry.icon)
                                                     : root.duck.icons.fallback
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (Style.font.heading + Style.spacing.lg) - Style.spacing.lg
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: appRow.entry ? appRow.entry.name : (appRow.modelData + "  (not found)")
                                color: appRow.entry ? Color.foreground : Qt.darker(Color.foreground, 1.5)
                                font.family: Style.font.menuFamily
                                font.pixelSize: Style.font.body
                            }
                        }

                        Row {
                            id: appControls

                            anchors.right: parent.right
                            anchors.rightMargin: Style.spacing.rowPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.spacing.sm

                            Button {
                                iconText: ""
                                bordered: true
                                enabled: appRow.index > 0
                                onClicked: root.apps.move(appRow.index, appRow.index - 1)
                            }
                            Button {
                                iconText: ""
                                bordered: true
                                enabled: appRow.index < root.config.apps.length - 1
                                onClicked: root.apps.move(appRow.index, appRow.index + 1)
                            }
                            Button {
                                iconText: ""
                                bordered: true
                                onClicked: root.apps.unpin(appRow.modelData)
                            }
                        }
                    }
                }

                Item { width: 1; height: Style.spacing.huge }

                Text {
                    width: content.width
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    color: Qt.darker(Color.foreground, 1.6)
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                    lineHeight: 1.4
                    text: "Add apps with  duck add <name>.  In the dock: drag to reorder, "
                          + "right-click to pin or unpin, middle-click for a new window."
                }
            }
        }
    }
}
