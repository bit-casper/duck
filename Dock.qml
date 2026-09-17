import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

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
    // The plugin root: carries config, the app model, icons and the Hyprland
    // values Style does not expose.
    required property var duck

    readonly property var config: duck.config
    readonly property var apps: duck.apps

    screen: modelData
    color: "transparent"

    anchors {
        left: true
        right: true
        bottom: true
    }

    // --- geometry -----------------------------------------------------------

    readonly property int borderWidth: win.config.bordered ? duck.hypr.borderWidth : 0

    // Icon size follows Omarchy's type scale rather than a setting. These are
    // logical pixels, so the compositor already scales them by the display
    // scale — the dock grows and shrinks with the user's scaling on its own.
    readonly property int iconSize: Math.max(16, Math.round(24 * (Style.font.baseSize / 12) * Style.spacing.scale))
    readonly property int padding: Style.spacing.lg

    readonly property int slotSize: iconSize + Style.spacing.xxl
    readonly property int dockHeight: slotSize + padding * 2 + borderWidth * 2

    // Matches the gap every ordinary window keeps from the screen edge.
    readonly property int gap: duck.hypr.windowGap
    // Where the dock body ends inside the borderless fade, which runs a gap
    // taller than the body so it can reach the screen edge.
    readonly property real fadeEnd: dockHeight / (dockHeight + gap)
    // Reserved above the dock so tooltips render inside the panel surface.
    readonly property int tipHeight: Style.spacing.huge + Style.font.body + Style.spacing.lg

    implicitHeight: tipHeight + dockHeight + gap

    // --- visibility ---------------------------------------------------------

    property bool mouseOpen: false
    property bool keyOpen: false
    readonly property bool open: mouseOpen || keyOpen

    property int selectedIndex: -1

    readonly property var items: win.apps.items

    function show(keyboard) {
        if (keyboard) {
            win.keyOpen = true;
            if (win.selectedIndex < 0 && win.items.length > 0) win.selectedIndex = 0;
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

    // Navigation, driven by the global bindings in hypr/duck.lua rather than by
    // key events.
    function nav(action) {
        if (action === "toggle") {
            win.toggle();
            return;
        }

        // Super+Ctrl+Left/Right belong to Hyprland's grouped-window focus when
        // the dock is down. Duck borrows them only while it is on screen and
        // hands the keypress back otherwise, so the original binding still
        // works rather than being silently taken over.
        //
        // The test is whether the dock is up, not how it was raised. Keying off
        // keyOpen meant a dock opened by hovering the screen edge still forwarded
        // the arrows away, so it sat there visibly open and ignoring the keyboard.
        if (!win.open && (action === "prev" || action === "next")) {
            Quickshell.execDetached(["hyprctl", "dispatch",
                action === "prev" ? "hl.dsp.group.prev()" : "hl.dsp.group.next()"]);
            return;
        }

        const count = win.items.length;
        if (count === 0) {
            if (action === "activate") win.hide();
            return;
        }

        // Using the keyboard claims a dock the mouse opened. Without this the
        // hide timer, armed when the pointer leaves, would pull the dock out
        // from under someone who had started navigating it.
        win.keyOpen = true;
        hideTimer.stop();

        // Start from whatever the pointer is on rather than the first icon, so
        // the first arrow press moves from where the user is looking.
        if (win.selectedIndex < 0)
            win.selectedIndex = hoverArea.hoverIndex >= 0 ? hoverArea.hoverIndex : 0;

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
                const from = win.config.apps.indexOf(item.id);
                if (win.apps.move(from, from + step)) win.selectedIndex += step;
            } else {
                // A running-only app has no stored position; moving it pins it.
                const target = Math.max(0, Math.min(win.config.apps.length, win.selectedIndex + step));
                if (win.apps.pinAt(item.id, target)) win.selectedIndex = target;
            }
            return;
        }

        if (action === "activate") {
            if (item) win.apps.activate(item);
            win.hide();
            return;
        }

        if (action === "unpin") {
            if (item && item.pinned) {
                win.apps.unpin(item.id);
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
    exclusiveZone: (win.config.pushWindows && open) ? (dockHeight + gap) : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "duck-dock"
    // Never takes keyboard focus. An Exclusive grab routes every keystroke to
    // the dock and leaves the desktop feeling frozen, and OnDemand delivers no
    // keys at all. Navigation arrives instead through the global shortcuts in
    // Duck.qml, bound in hypr/duck.lua to Super combinations only, so every
    // other key types through to the focused window untouched.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        x: 0
        y: win.open ? 0 : win.implicitHeight - 1
        width: win.width
        // Zero height while closed with edge-reveal off: fully click-through
        // until a keybinding raises it.
        height: win.open ? win.implicitHeight : (win.config.edgeReveal ? 1 : 0)
    }

    Timer {
        id: hideTimer
        interval: win.config.hideDelay
        // Closes outright rather than only dropping mouseOpen: a dock raised
        // from the keyboard has to answer the pointer leaving it too, and
        // clearing mouseOpen alone would leave keyOpen holding it on screen.
        onTriggered: win.hide()
    }

    Timer {
        id: revealTimer
        interval: win.config.revealDelay
        onTriggered: if (hoverArea.containsMouse && win.config.edgeReveal) win.mouseOpen = true
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
                enabled: win.config.animate
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
                    x: Math.max(win.gap,
                         Math.min(win.width - width - win.gap,
                           row.x + (tip.item ? win.indexOf(tip.item) * win.slotSize : 0)
                             + win.slotSize / 2 - width / 2))

                    // Capped at the screen: the label is app-supplied and a long
                    // enough name would otherwise size the tooltip past both edges.
                    implicitWidth: Math.min(tipLabel.implicitWidth + Style.spacing.rowPaddingX * 2,
                                            win.width - win.gap * 2)
                    implicitHeight: tipLabel.implicitHeight + Style.spacing.md * 2
                    radius: Style.cornerRadius

                    color: Color.tooltip.background
                    border.width: duck.hypr.borderWidth
                    border.color: Color.tooltip.border

                    Text {
                        id: tipLabel

                        anchors.centerIn: parent
                        width: tipBox.width - Style.spacing.rowPaddingX * 2
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter

                        // The name reaches here from a .desktop file's Name or,
                        // for an unresolved running app, straight from the window
                        // title — neither of which Duck controls. AutoText would
                        // sniff those for markup and render it, so pin the format
                        // rather than trusting what an application calls itself.
                        textFormat: Text.PlainText
                        text: tip.item ? tip.item.name : ""

                        color: Color.tooltip.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
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
                    visible: win.config.bordered
                    color: Color.background
                    border.width: win.borderWidth
                    border.color: Color.accent
                    radius: Style.cornerRadius
                }

                // Borderless: no chrome, just a fade up from the screen edge.
                //
                // The window gap belongs to the bordered dock, which has to sit
                // exactly where a window would. A fade has no such reason to hold
                // off the edges, and keeping the inset here left an unshaded
                // strip of desktop along the bottom and sides of the screen.
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -win.gap
                    anchors.rightMargin: -win.gap
                    anchors.bottomMargin: -win.gap
                    visible: !win.config.bordered

                    // Only the top corners are ever visible; rounding the two
                    // that sit on the screen edge would notch the shading.
                    topLeftRadius: Style.cornerRadius
                    topRightRadius: Style.cornerRadius

                    // Scaled so the fade across the dock body reads the same as
                    // it did before the gap was covered, then held steady over
                    // the last stretch down to the edge.
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.0) }
                        GradientStop { position: 0.55 * win.fadeEnd; color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.65) }
                        GradientStop { position: win.fadeEnd; color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.95) }
                        GradientStop { position: 1.0; color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.95) }
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
                            config: win.config
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
                    width: Math.max(2, duck.hypr.borderWidth)
                    height: win.slotSize
                    color: Color.accent
                    y: (body.height - height) / 2
                    x: row.x + drag.toIndex * win.slotSize - width / 2
                }

                // Icon ghost following the cursor during a drag.
                DockItem {
                    visible: drag.active && drag.item !== null
                    item: drag.item !== null ? drag.item : { "icon": "", "name": "", "running": false, "windows": [] }
                    config: win.config
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
            return Math.max(0, Math.min(win.config.apps.length, slot));
        }

        onEntered: {
            hideTimer.stop();
            if (!win.open && win.config.edgeReveal) revealTimer.restart();
        }

        // Always arm the timer, however the dock was raised. Skipping it while
        // keyOpen meant a dock opened from the keyboard could not be dismissed
        // by moving the pointer off it -- the one mouse gesture people reach for
        // first. The pointer has to have been over the dock for this to fire at
        // all, so a keyboard user whose mouse is elsewhere is unaffected.
        onExited: {
            revealTimer.stop();
            hoverIndex = -1;
            hideTimer.restart();
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
                    const from = win.config.apps.indexOf(item.id);
                    // Dropping right of its own slot shifts the target left one.
                    const to = drag.toIndex > from ? drag.toIndex - 1 : drag.toIndex;
                    win.apps.move(from, to);
                } else {
                    win.apps.pinAt(item.id, drag.toIndex);
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
                // Launching or focusing an app is the end of the interaction
                // whichever way the dock was raised, so it closes either way.
                win.apps.activate(item);
                win.hide();
            } else if (mouse.button === Qt.MiddleButton) {
                win.apps.launch(item);
            } else if (mouse.button === Qt.RightButton) {
                if (item.pinned) win.apps.unpin(item.id);
                else win.apps.pin(item.id);
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
