import QtQuick
import Quickshell
import Quickshell.Wayland

// The dock surface: a layer-shell panel along the bottom edge.
//
// The window is always mapped at full height; hiding slides the content below
// the screen edge and shrinks the input mask to a 1px strip. That strip is what
// makes bottom-edge hover work without a second window, and it means a hidden
// dock never eats clicks meant for the windows underneath.
//
// The panel itself stays flush with the screen edge even though the dock body is
// inset by the window gap — otherwise the hotspot would sit a gap's width above
// the edge and the mouse would never reach it.
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

    // Icon size follows Omarchy's type scale rather than a setting. These are
    // logical pixels, so the compositor already scales them by the display
    // scale — the dock grows and shrinks with the user's scaling on its own.
    readonly property int iconSize: Math.max(16, Math.round(24 * (Theme.fontBase / 12) * Theme.spacingScale))
    readonly property int padding: Theme.spacingLg

    readonly property int slotSize: iconSize + Theme.spacingXxl
    readonly property int dockHeight: slotSize + padding * 2 + borderWidth * 2

    // Matches the gap every ordinary window keeps from the screen edge.
    readonly property int gap: Theme.windowGap
    // Reserved above the dock so tooltips render inside the panel surface.
    readonly property int tipHeight: Theme.spacingHuge + Theme.fontBody + Theme.spacingLg

    implicitHeight: tipHeight + dockHeight + gap

    // --- visibility ---------------------------------------------------------

    property bool mouseOpen: false
    property bool keyOpen: false
    readonly property bool open: mouseOpen || keyOpen

    property int selectedIndex: -1

    readonly property var items: Apps.items

    function submap(name) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"" + name + "\")"]);
    }

    function show(keyboard) {
        if (keyboard) {
            const wasOpen = win.keyOpen;
            win.keyOpen = true;
            if (win.selectedIndex < 0 && win.items.length > 0) win.selectedIndex = 0;
            if (!wasOpen) submap("duck");
        } else {
            win.mouseOpen = true;
        }
    }

    function hide() {
        const wasKeyboard = win.keyOpen;

        win.mouseOpen = false;
        win.keyOpen = false;
        win.selectedIndex = -1;
        drag.reset();

        // Always hand the keyboard back, however the dock came to close.
        if (wasKeyboard) submap("reset");
    }

    // Navigation, driven by the submap rather than by key events.
    function nav(action) {
        if (action === "toggle") {
            win.toggle();
            return;
        }

        // Super+Ctrl+Left/Right belong to Hyprland's grouped-window focus when
        // the dock is down. Duck borrows them only while it is on screen and
        // hands the keypress back otherwise, so the original binding still
        // works rather than being silently taken over.
        if (!win.keyOpen && (action === "prev" || action === "next")) {
            Quickshell.execDetached(["hyprctl", "dispatch",
                action === "prev" ? "hl.dsp.group.prev()" : "hl.dsp.group.next()"]);
            return;
        }

        const count = win.items.length;
        if (count === 0) {
            if (action === "activate") win.hide();
            return;
        }

        if (win.selectedIndex < 0) win.selectedIndex = 0;
        const item = win.items[win.selectedIndex];

        if (action === "prev" || action === "next") {
            const step = action === "prev" ? -1 : 1;
            win.selectedIndex = (win.selectedIndex + step + count) % count;
            return;
        }

        if (action === "moveprev" || action === "movenext") {
            const step = action === "moveprev" ? -1 : 1;
            if (!item) return;

            if (item.pinned) {
                const from = Config.apps.indexOf(item.id);
                if (Apps.move(from, from + step)) win.selectedIndex += step;
            } else {
                // A running-only app has no stored position; moving it pins it.
                const target = Math.max(0, Math.min(Config.apps.length, win.selectedIndex + step));
                if (Apps.pinAt(item.id, target)) win.selectedIndex = target;
            }
            return;
        }

        if (action === "activate") {
            if (item) Apps.activate(item);
            win.hide();
            return;
        }

        if (action === "unpin") {
            if (item && item.pinned) {
                Apps.unpin(item.id);
                win.selectedIndex = Math.max(0, Math.min(win.selectedIndex, win.items.length - 2));
            }
        }
    }

    function toggle() {
        if (win.open) win.hide();
        else win.show(true);
    }

    // Push mode only reserves space while the dock is on screen; otherwise an
    // auto-hiding dock would permanently shrink the workspace.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: (Config.pushWindows && open) ? (dockHeight + gap) : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "duck-dock"
    // Never takes keyboard focus. An Exclusive grab routes every keystroke to
    // the dock and leaves the desktop feeling frozen, and OnDemand delivers no
    // keys at all. Navigation arrives instead as IPC calls from the Hyprland
    // submap declared in hypr/duck.lua, which rebinds only the arrow keys and
    // lets everything else type through to the focused window.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        x: 0
        y: win.open ? 0 : win.implicitHeight - 1
        width: win.width
        // Zero height while closed with edge-reveal off: fully click-through
        // until a keybinding raises it.
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

    // Plain container: the dock receives no key events of its own, so there is
    // nothing here to focus. Navigation comes in through nav() via IPC.
    Item {
        id: keyScope

        anchors.fill: parent

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
                    visible: tip.item !== null && !drag.active
                    anchors.verticalCenter: parent.verticalCenter

                    // Follow the icon, but never hang off either screen edge.
                    x: Math.max(win.gap,
                         Math.min(win.width - width - win.gap,
                           row.x + (tip.item ? win.indexOf(tip.item) * win.slotSize : 0)
                             + win.slotSize / 2 - width / 2))

                    implicitWidth: tipLabel.implicitWidth + Theme.rowPaddingX * 2
                    implicitHeight: tipLabel.implicitHeight + Theme.spacingMd * 2
                    radius: Theme.cornerRadius

                    color: Theme.tooltipBackground
                    border.width: Theme.borderWidth
                    border.color: Theme.tooltipBorder

                    Text {
                        id: tipLabel
                        anchors.centerIn: parent
                        text: tip.item ? tip.item.name : ""
                        color: Theme.tooltipText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                }
            }

            // Dock body, inset exactly like an ordinary window.
            Item {
                id: body

                anchors.bottom: parent.bottom
                anchors.bottomMargin: win.gap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: win.gap
                anchors.rightMargin: win.gap
                height: win.dockHeight

                // Bordered: solid themed panel with the same border and corner
                // radius Hyprland draws on windows.
                Rectangle {
                    anchors.fill: parent
                    visible: Config.bordered
                    color: Theme.background
                    border.width: win.borderWidth
                    border.color: Theme.accent
                    radius: Theme.cornerRadius
                }

                // Borderless: no chrome, just a fade up from the screen edge.
                Rectangle {
                    anchors.fill: parent
                    visible: !Config.bordered
                    radius: Theme.cornerRadius

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
                            iconSize: win.iconSize
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
                    width: Math.max(2, Theme.borderWidth)
                    height: win.slotSize
                    color: Theme.accent
                    y: (body.height - height) / 2
                    x: row.x + drag.toIndex * win.slotSize - width / 2
                }

                // Icon ghost following the cursor during a drag.
                DockItem {
                    visible: drag.active && drag.item !== null
                    item: drag.item !== null ? drag.item : { "icon": "", "name": "", "running": false, "windows": [] }
                    iconSize: win.iconSize
                    width: win.slotSize
                    height: win.slotSize
                    opacity: 0.85
                    x: hoverArea.mouseX - body.x - width / 2
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

            const localX = x - row.x - body.x;
            if (localX < 0 || localX >= row.width) return -1;

            const index = Math.floor(localX / win.slotSize);
            return (index >= 0 && index < win.items.length) ? index : -1;
        }

        // Where a dragged icon would land, measured between slots.
        function dropAt(x) {
            const localX = x - row.x - body.x;
            const slot = Math.round(localX / win.slotSize);
            return Math.max(0, Math.min(Config.apps.length, slot));
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

            // Every icon can be dragged. A running-but-unpinned app gets pinned
            // wherever it is dropped, which is the only sense "move this one"
            // can have for an app with no stored position.
            if (mouse.button === Qt.LeftButton && index >= 0) drag.fromIndex = index;
        }

        onReleased: function (mouse) {
            if (drag.active && drag.toIndex >= 0 && drag.item !== null) {
                const item = drag.item;

                if (item.pinned) {
                    const from = Config.apps.indexOf(item.id);
                    // Dropping right of its own slot shifts the target left one.
                    const to = drag.toIndex > from ? drag.toIndex - 1 : drag.toIndex;
                    Apps.move(from, to);
                } else {
                    Apps.pinAt(item.id, drag.toIndex);
                }

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
