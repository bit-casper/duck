import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The dock surface: a full-width layer-shell panel pinned to the bottom edge.
//
// The window is always mapped at its full height; hiding is done by sliding the
// content below the screen edge and shrinking the input mask to a 1px strip.
// That strip is what makes bottom-edge hover work without a separate hotspot
// window, and it means a hidden dock never eats clicks meant for other windows.
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    color: "transparent"

    anchors {
        left: true
        right: true
        bottom: true
    }

    // --- geometry -----------------------------------------------------------

    readonly property int borderWidth: Config.bordered ? Theme.borderWidth : 0
    readonly property int slotSize: Config.iconSize + 12
    readonly property int dockHeight: slotSize + Config.padding * 2 + borderWidth * 2
    // Reserved above the dock so tooltips render inside the panel surface.
    readonly property int tipHeight: 30

    implicitHeight: dockHeight + tipHeight

    // --- visibility ---------------------------------------------------------

    property bool mouseOpen: false
    property bool keyOpen: false
    readonly property bool open: mouseOpen || keyOpen

    // Keyboard cursor; -1 means "no selection".
    property int selectedIndex: -1

    readonly property var items: Apps.items

    function show(keyboard) {
        if (keyboard) {
            win.keyOpen = true;
            if (win.selectedIndex < 0 && win.items.length > 0) win.selectedIndex = 0;
            keyScope.forceActiveFocus();
        } else {
            win.mouseOpen = true;
        }
    }

    function hide() {
        win.mouseOpen = false;
        win.keyOpen = false;
        win.selectedIndex = -1;
        drag.reset();
    }

    function toggle() {
        if (win.open) win.hide();
        else win.show(true);
    }

    // Push mode only reserves space while the dock is actually on screen,
    // otherwise an auto-hiding dock would permanently shrink the workspace.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: (Config.pushWindows && open) ? dockHeight : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "duck-dock"
    // Only grab the keyboard when raised by key, so edge-hover never steals typing.
    WlrLayershell.keyboardFocus: keyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        x: 0
        y: win.open ? 0 : win.implicitHeight - 1
        width: win.width
        // Zero height while closed with edge-reveal off: the dock becomes
        // completely click-through until a keybinding raises it.
        height: win.open ? win.implicitHeight : (Config.edgeReveal ? 1 : 0)
    }

    Timer {
        id: hideTimer
        interval: Config.hideDelay
        onTriggered: if (!win.keyOpen) win.mouseOpen = false
    }

    Timer {
        id: revealTimer
        interval: Config.revealDelay
        onTriggered: if (hoverArea.containsMouse && Config.edgeReveal) win.mouseOpen = true
    }

    // --- content ------------------------------------------------------------

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
            const count = win.items.length;

            if (event.key === Qt.Key_Escape) {
                win.hide();
                event.accepted = true;
                return;
            }
            if (count === 0) return;

            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;

            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                const step = event.key === Qt.Key_Left ? -1 : 1;

                if (shift) {
                    // Reorder: only pinned entries have a stored position.
                    const item = win.items[win.selectedIndex];
                    if (item && item.pinned) {
                        const from = Config.apps.indexOf(item.id);
                        if (Apps.move(from, from + step)) win.selectedIndex += step;
                    }
                } else {
                    win.selectedIndex = (win.selectedIndex + step + count) % count;
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                const item = win.items[win.selectedIndex];
                if (item) {
                    Apps.activate(item);
                    win.hide();
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Delete || event.key === Qt.Key_Minus) {
                const item = win.items[win.selectedIndex];
                if (item && item.pinned) {
                    Apps.unpin(item.id);
                    win.selectedIndex = Math.min(win.selectedIndex, win.items.length - 2);
                }
                event.accepted = true;
            }
        }

        Item {
            id: slider

            width: parent.width
            height: win.implicitHeight
            y: win.open ? 0 : win.implicitHeight

            Behavior on y {
                enabled: Config.animate
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Tooltip, floating above the dock body.
            Item {
                id: tip

                height: win.tipHeight
                width: parent.width

                readonly property var item: {
                    if (win.selectedIndex >= 0 && win.selectedIndex < win.items.length)
                        return win.items[win.selectedIndex];
                    if (hoverArea.hoverIndex >= 0 && hoverArea.hoverIndex < win.items.length)
                        return win.items[hoverArea.hoverIndex];
                    return null;
                }

                Rectangle {
                    id: tipBox

                    visible: tip.item !== null && !drag.active
                    anchors.verticalCenter: parent.verticalCenter
                    // Follow the icon, but never hang off either screen edge.
                    x: Math.max(Config.gap,
                         Math.min(win.width - width - Config.gap,
                           row.x + (tip.item ? win.indexOf(tip.item) * win.slotSize : 0)
                             + win.slotSize / 2 - width / 2))

                    implicitWidth: tipLabel.implicitWidth + 16
                    implicitHeight: tipLabel.implicitHeight + 8

                    color: Theme.isDark ? Theme.darkBackground : Theme.background
                    border.width: Theme.borderWidth
                    border.color: Theme.accent

                    Text {
                        id: tipLabel
                        anchors.centerIn: parent
                        text: tip.item ? tip.item.name : ""
                        color: Theme.foreground
                        font.pixelSize: 12
                    }
                }
            }

            // Dock body.
            Item {
                id: body

                width: parent.width
                height: win.dockHeight
                anchors.bottom: parent.bottom

                // Bordered mode: a solid themed panel with the same square border
                // Hyprland draws on windows.
                Rectangle {
                    anchors.fill: parent
                    visible: Config.bordered
                    color: Theme.background
                    border.width: win.borderWidth
                    border.color: Theme.accent
                    radius: 0
                }

                // Borderless mode: no chrome, just a fade up from the screen edge.
                Rectangle {
                    anchors.fill: parent
                    visible: !Config.bordered

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.0) }
                        GradientStop { position: 0.55; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.65) }
                        GradientStop { position: 1.0; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95) }
                    }
                }

                Row {
                    id: row

                    anchors.centerIn: parent
                    spacing: 0

                    Repeater {
                        model: win.items

                        DockItem {
                            required property int index
                            required property var modelData

                            item: modelData
                            iconSize: Config.iconSize
                            width: win.slotSize
                            height: win.slotSize
                            selected: win.selectedIndex === index
                            hovered: hoverArea.hoverIndex === index && win.selectedIndex < 0
                            dragging: drag.active && drag.fromIndex === index
                        }
                    }
                }

                // Insertion caret shown while dragging.
                Rectangle {
                    visible: drag.active && drag.toIndex >= 0
                    width: 2
                    height: win.slotSize
                    color: Theme.accent
                    y: (body.height - height) / 2
                    x: row.x + drag.toIndex * win.slotSize - 1
                }

                // Icon ghost that follows the cursor during a drag.
                DockItem {
                    visible: drag.active && drag.item !== null
                    item: drag.item !== null ? drag.item : { "icon": "", "name": "", "running": false, "windows": [] }
                    iconSize: Config.iconSize
                    width: win.slotSize
                    height: win.slotSize
                    opacity: 0.85
                    x: hoverArea.mouseX - width / 2
                    y: (body.height - height) / 2
                }
            }
        }
    }

    // --- pointer handling ---------------------------------------------------

    QtObject {
        id: drag

        property bool active: false
        property int fromIndex: -1
        property int toIndex: -1
        property var item: null

        function reset() {
            active = false;
            fromIndex = -1;
            toIndex = -1;
            item = null;
        }
    }

    function indexOf(item) {
        for (let i = 0; i < win.items.length; i++) {
            if (win.items[i].key === item.key) return i;
        }
        return 0;
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        property int hoverIndex: -1
        property int pressIndex: -1
        property real pressX: 0

        // Maps a pointer position to a dock slot, or -1 when outside the icons.
        function slotAt(x, y) {
            const localY = y - slider.y - tip.height;
            if (localY < 0 || localY > win.dockHeight) return -1;

            const localX = x - row.x;
            if (localX < 0 || localX >= row.width) return -1;

            const index = Math.floor(localX / win.slotSize);
            return (index >= 0 && index < win.items.length) ? index : -1;
        }

        // Where a dragged icon would land, measured between slots.
        function dropAt(x) {
            const pinnedCount = Config.apps.length;
            const localX = x - row.x;
            const slot = Math.round(localX / win.slotSize);
            return Math.max(0, Math.min(pinnedCount, slot));
        }

        onEntered: {
            hideTimer.stop();
            if (!win.open && Config.edgeReveal) revealTimer.restart();
        }

        onExited: {
            revealTimer.stop();
            hoverIndex = -1;
            if (!win.keyOpen) hideTimer.restart();
        }

        onPositionChanged: function (mouse) {
            hoverIndex = slotAt(mouse.x, mouse.y);

            if (drag.fromIndex >= 0 && !drag.active && Math.abs(mouse.x - pressX) > 8) {
                drag.active = true;
                drag.item = win.items[drag.fromIndex];
            }
            if (drag.active) drag.toIndex = dropAt(mouse.x);
        }

        onPressed: function (mouse) {
            const index = slotAt(mouse.x, mouse.y);
            pressIndex = index;
            pressX = mouse.x;

            // Only pinned apps have a stored order, so only they can be dragged.
            if (mouse.button === Qt.LeftButton && index >= 0 && win.items[index].pinned)
                drag.fromIndex = index;
        }

        onReleased: function (mouse) {
            if (drag.active && drag.toIndex >= 0) {
                const from = Config.apps.indexOf(win.items[drag.fromIndex].id);
                // Dropping to the right of its own slot shifts the target left by one.
                const to = drag.toIndex > from ? drag.toIndex - 1 : drag.toIndex;
                Apps.move(from, to);
                drag.reset();
                pressIndex = -1;
                return;
            }

            drag.reset();
            const index = slotAt(mouse.x, mouse.y);
            if (index < 0 || index !== pressIndex) {
                pressIndex = -1;
                return;
            }

            const item = win.items[index];
            pressIndex = -1;

            if (mouse.button === Qt.LeftButton) {
                Apps.activate(item);
                if (win.keyOpen) win.hide();
            } else if (mouse.button === Qt.MiddleButton) {
                Apps.launch(item);
            } else if (mouse.button === Qt.RightButton) {
                if (item.pinned) Apps.unpin(item.id);
                else Apps.pin(item.id);
            }
        }
    }

    // Selection follows the mouse so hover and keyboard never disagree.
    Connections {
        target: hoverArea
        function onHoverIndexChanged() {
            if (win.keyOpen && hoverArea.hoverIndex >= 0) win.selectedIndex = hoverArea.hoverIndex;
        }
    }
}
