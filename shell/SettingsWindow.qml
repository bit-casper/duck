import QtQuick
import Quickshell
import Quickshell.Widgets

// Duck's settings.
//
// Writes straight to config.json through Config.set(), which the dock is
// already watching, so every change previews live on the real dock.
//
// No border is drawn here: this is an ordinary Hyprland window and the
// compositor already draws the themed border around it. Drawing our own on top
// is what made this window's edge read heavier than every other window.
FloatingWindow {
    id: root

    implicitWidth: 520
    implicitHeight: 720
    title: "Duck Settings"
    color: Theme.background

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        Flickable {
            id: scroll

            anchors.fill: parent
            anchors.margins: Theme.panelPadding
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: scroll.width
                spacing: 0

                Item {
                    width: parent.width
                    implicitHeight: header.implicitHeight + Theme.spacingLg

                    Column {
                        id: header
                        x: Theme.rowPaddingX
                        spacing: Theme.spacingXs

                        Text {
                            text: "Duck"
                            color: Theme.foreground
                            font.family: Theme.menuFontFamily
                            font.pixelSize: Theme.fontHeading
                            font.bold: true
                        }

                        Text {
                            text: "Dock settings"
                            color: Qt.darker(Theme.foreground, 1.5)
                            font.family: Theme.menuFontFamily
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }

                // --- appearance ---------------------------------------------

                SettingsSection { title: "Appearance" }

                SettingsToggle {
                    label: "Bordered"
                    description: checked ? "Square themed border and solid background, like an ordinary window"
                                         : "No border, with a gradient fading up from the screen edge"
                    checked: Config.bordered
                    onToggled: Config.set("bordered", !Config.bordered)
                }

                SettingsToggle {
                    label: "Animations"
                    description: "Slide and hover transitions"
                    checked: Config.animate
                    onToggled: Config.set("animate", !Config.animate)
                }

                // Icon size is derived, not configured. Say so, so its absence
                // reads as a decision rather than a missing control.
                Item {
                    width: parent.width
                    implicitHeight: sizeNote.implicitHeight + Theme.spacingXl

                    Text {
                        id: sizeNote
                        x: Theme.rowPaddingX
                        width: parent.width - Theme.rowPaddingX * 2
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        color: Qt.darker(Theme.foreground, 1.5)
                        font.family: Theme.menuFontFamily
                        font.pixelSize: Theme.fontCaption
                        text: "Icon size follows your theme's type scale and display scaling — "
                              + "currently " + Math.max(16, Math.round(24 * (Theme.fontBase / 12) * Theme.spacingScale))
                              + "px at " + Theme.scale + "× scaling."
                    }
                }

                // --- behavior -----------------------------------------------

                SettingsSection { title: "Behavior" }

                SettingsToggle {
                    label: "Push windows up"
                    description: checked ? "Windows resize to make room for the dock"
                                         : "Dock overlays whatever is on screen"
                    checked: Config.pushWindows
                    onToggled: Config.set("pushWindows", !Config.pushWindows)
                }

                SettingsToggle {
                    label: "Show running apps"
                    description: checked ? "Running apps you have not pinned appear after the pinned ones"
                                         : "Only pinned apps are shown"
                    checked: Config.showRunning
                    onToggled: Config.set("showRunning", !Config.showRunning)
                }

                SettingsToggle {
                    label: "Reveal on bottom edge"
                    description: checked ? "Dock slides up when the mouse reaches the edge"
                                         : "Keyboard only (Super+Ctrl+Down)"
                    checked: Config.edgeReveal
                    onToggled: Config.set("edgeReveal", !Config.edgeReveal)
                }

                SettingsStepper {
                    label: "Reveal delay"
                    description: "How long the mouse rests at the edge first"
                    value: Config.revealDelay
                    suffix: " ms"
                    minimum: 0
                    maximum: 1000
                    step: 30
                    enabled: Config.edgeReveal
                    opacity: Config.edgeReveal ? 1 : 0.4
                    onChanged: function (next) { Config.set("revealDelay", next); }
                }

                SettingsStepper {
                    label: "Hide delay"
                    description: "How long the dock waits after the mouse leaves"
                    value: Config.hideDelay
                    suffix: " ms"
                    minimum: 0
                    maximum: 2000
                    step: 50
                    onChanged: function (next) { Config.set("hideDelay", next); }
                }

                // --- pinned apps --------------------------------------------

                SettingsSection { title: "Pinned apps" }

                Item {
                    width: parent.width
                    visible: Config.apps.length === 0
                    implicitHeight: visible ? empty.implicitHeight + Theme.spacingXl : 0

                    Text {
                        id: empty
                        x: Theme.rowPaddingX
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Nothing pinned yet — try  duck add ghostty"
                        color: Qt.darker(Theme.foreground, 1.5)
                        font.family: Theme.menuFontFamily
                        font.pixelSize: Theme.fontCaption
                    }
                }

                Repeater {
                    model: Config.apps

                    Item {
                        id: appRow

                        required property int index
                        required property string modelData

                        readonly property var entry: Apps.entryFor(modelData)
                        readonly property bool hot: rowHover.hovered

                        width: content.width
                        implicitHeight: Theme.controlHeight + Theme.spacingXl

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: appRow.hot ? Theme.fill("hover-cursor") : "transparent"

                            Behavior on color {
                                enabled: Config.animate
                                ColorAnimation { duration: 100 }
                            }
                        }

                        HoverHandler { id: rowHover }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.rowPaddingX
                            anchors.right: appControls.left
                            anchors.rightMargin: Theme.rowPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingLg

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Theme.fontHeading + Theme.spacingLg
                                source: appRow.entry ? Icons.source(appRow.entry.icon) : Icons.fallback
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (Theme.fontHeading + Theme.spacingLg) - Theme.spacingLg
                                elide: Text.ElideRight
                                text: appRow.entry ? appRow.entry.name : (appRow.modelData + "  (not found)")
                                color: appRow.entry ? Theme.foreground : Qt.darker(Theme.foreground, 1.5)
                                font.family: Theme.menuFontFamily
                                font.pixelSize: Theme.fontBody
                            }
                        }

                        Row {
                            id: appControls

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.rowPaddingX
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingSm

                            SettingsButton {
                                text: "←"
                                enabled: appRow.index > 0
                                onClicked: Apps.move(appRow.index, appRow.index - 1)
                            }
                            SettingsButton {
                                text: "→"
                                enabled: appRow.index < Config.apps.length - 1
                                onClicked: Apps.move(appRow.index, appRow.index + 1)
                            }
                            SettingsButton {
                                text: "✕"
                                danger: true
                                onClicked: Apps.unpin(appRow.modelData)
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.spacingHuge }

                Text {
                    x: Theme.rowPaddingX
                    width: content.width - Theme.rowPaddingX * 2
                    wrapMode: Text.WordWrap
                    color: Qt.darker(Theme.foreground, 1.6)
                    font.family: Theme.menuFontFamily
                    font.pixelSize: Theme.fontCaption
                    lineHeight: 1.4
                    text: "Add apps with  duck add <name>.  In the dock: drag to reorder, "
                          + "right-click to pin or unpin, middle-click for a new window."
                }
            }
        }
    }
}
