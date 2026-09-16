import QtQuick
import Quickshell
import Quickshell.Widgets

// Duck's settings. Writes straight to config.json through Config.set(), which the
// dock is already watching — so every change previews live on the real dock.
FloatingWindow {
    id: root

    implicitWidth: 460
    implicitHeight: 620
    title: "Duck Settings"
    color: Theme.background

    // Shared row metrics.
    readonly property int pad: 18

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.width: Theme.borderWidth
        border.color: Theme.accent

        Flickable {
            anchors.fill: parent
            anchors.margins: root.pad
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: parent.width
                spacing: 6

                Text {
                    text: "Duck"
                    color: Theme.foreground
                    font.pixelSize: 22
                    font.bold: true
                }

                Text {
                    text: "Dock settings · theme: " + Theme.mode
                    color: Theme.muted
                    font.pixelSize: 12
                    bottomPadding: 10
                }

                // --- appearance ---------------------------------------------

                SettingsSection { title: "Appearance" }

                SettingsToggle {
                    label: "Bordered"
                    description: checked ? "Square themed border, solid background"
                                         : "No border, gradient fade from the bottom"
                    checked: Config.bordered
                    onToggled: Config.set("bordered", !Config.bordered)
                }

                SettingsToggle {
                    label: "Animations"
                    description: "Slide and hover transitions"
                    checked: Config.animate
                    onToggled: Config.set("animate", !Config.animate)
                }

                SettingsStepper {
                    label: "Icon size"
                    value: Config.iconSize
                    suffix: " px"
                    minimum: 24
                    maximum: 96
                    step: 4
                    onChanged: function (next) { Config.set("iconSize", next); }
                }

                SettingsStepper {
                    label: "Padding"
                    value: Config.padding
                    suffix: " px"
                    minimum: 0
                    maximum: 32
                    step: 2
                    onChanged: function (next) { Config.set("padding", next); }
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
                    description: checked ? "Unpinned running apps appear at the end"
                                         : "Only pinned apps are shown"
                    checked: Config.showRunning
                    onToggled: Config.set("showRunning", !Config.showRunning)
                }

                SettingsToggle {
                    label: "Reveal on bottom edge"
                    description: checked ? "Dock slides up when the mouse hits the edge"
                                         : "Keyboard only (Super+Ctrl+Down)"
                    checked: Config.edgeReveal
                    onToggled: Config.set("edgeReveal", !Config.edgeReveal)
                }

                SettingsStepper {
                    label: "Reveal delay"
                    value: Config.revealDelay
                    suffix: " ms"
                    minimum: 0
                    maximum: 1000
                    step: 30
                    onChanged: function (next) { Config.set("revealDelay", next); }
                }

                SettingsStepper {
                    label: "Hide delay"
                    value: Config.hideDelay
                    suffix: " ms"
                    minimum: 0
                    maximum: 2000
                    step: 50
                    onChanged: function (next) { Config.set("hideDelay", next); }
                }

                // --- pinned apps --------------------------------------------

                SettingsSection { title: "Pinned apps" }

                Text {
                    text: Config.apps.length === 0 ? "Nothing pinned yet — try `duck add ghostty`." : ""
                    visible: Config.apps.length === 0
                    color: Theme.muted
                    font.pixelSize: 12
                    bottomPadding: 6
                }

                Repeater {
                    model: Config.apps

                    Rectangle {
                        id: appRow

                        required property int index
                        required property string modelData

                        readonly property var entry: Apps.entryFor(modelData)

                        width: content.width
                        height: 44
                        color: Theme.background

                        // Faint backplate that still reads on light themes.
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.foreground
                            opacity: 0.05
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: appControls.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 24
                                source: appRow.entry ? Icons.source(appRow.entry.icon) : Icons.fallback
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 32
                                elide: Text.ElideRight
                                text: appRow.entry ? appRow.entry.name : (appRow.modelData + "  (not found)")
                                color: appRow.entry ? Theme.foreground : Theme.muted
                                font.pixelSize: 13
                            }
                        }

                        Row {
                            id: appControls

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            SettingsButton {
                                text: "\u2190"
                                enabled: appRow.index > 0
                                onClicked: Apps.move(appRow.index, appRow.index - 1)
                            }
                            SettingsButton {
                                text: "\u2192"
                                enabled: appRow.index < Config.apps.length - 1
                                onClicked: Apps.move(appRow.index, appRow.index + 1)
                            }
                            SettingsButton {
                                text: "\u2715"
                                danger: true
                                onClicked: Apps.unpin(appRow.modelData)
                            }
                        }
                    }
                }

                Item { width: 1; height: 12 }

                Text {
                    text: "Add apps from the terminal:  duck add <name>\n" +
                          "Right-click an icon in the dock to unpin it."
                    color: Theme.muted
                    font.pixelSize: 11
                    lineHeight: 1.4
                }
            }
        }
    }
}
