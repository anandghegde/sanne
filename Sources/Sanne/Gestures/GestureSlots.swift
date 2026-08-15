import Foundation

/// Fixed remappable gesture slots (Sanne Standard map). Overrides stored in config by `id`.
enum GestureSlots {
    enum Group: String, CaseIterable, Identifiable, Hashable {
        case magicMouse = "Magic Mouse"
        case titlebar = "Titlebar"
        case dock = "Dock"
        case menubar = "Menubar"
        case trackpad = "Trackpad free-space"
        case keyboard = "Keyboard"

        var id: String { rawValue }
    }

    /// How the slot relates to legacy section toggles when no override exists.
    enum LegacyGate {
        case magicMouseMaster
        case mmLeftTap
        case mmRightTap
        case mmMiddleTwo
        case mmMiddleThree
        case mmMultiClick // not a separate slot action gate for multi; reserved
        case mmTapDrag
        case mmTwoFingerDoubleMC
        case mmTwoFingerSwipeUp
        case mmTwoFingerSwipeDown
        case mmTwoFingerSpaces
        case mmThreeFingerSwipes
        case mmTwoFingerTopEdgeMove
        case mmThreeFingerTopEdgeResize
        case mmOneFingerSwipePages
        case mmTipTap
        case mmTipTapMiddle
        case titlebarMaster
        case tbHalves
        case tbThirds
        case tbQuarters
        case tbMaximize
        case tbMinimize
        case tbPinchClose
        case tbPinchFullscreen
        case tbThreeFingerDisplay
        case dockMaster
        case dockActivate
        case dockHide
        case dockNew
        case dockQuit
        case menubarMaster
        case mbCycle
        case mbHideOthers
        case mbUnminimize
        case trackpadMiddle
        case trackpadThreeFingerDrag
        case trackpadFreeThreeSwipe
        case trackpadFreeFourSwipe
        case trackpadFreeFourTap
        case trackpadTipTap
        case trackpadTipTapMiddle
        case trackpadThreeFingerTipTap
        case trackpadThreeFingerClick
        case trackpadCornerTaps
        case keyboardSnap
        case keyboardDisplay
    }

    enum Visibility: String, Hashable {
        /// Everyday slots (on by default).
        case simple
        /// Off by default or power-user slots. Device pages list these with the rest.
        case advanced
    }

    struct Slot: Identifiable, Hashable {
        let id: String
        let group: Group
        let title: String
        let detail: String
        let defaultActionId: String
        let legacyGate: LegacyGate
        /// When true, action cannot be remapped (only enable/disable).
        let actionFixed: Bool
        var visibility: Visibility = .advanced
        /// Sanne Standard default when no override exists. Off-by-default slots set this false.
        var defaultEnabled: Bool = true

        var defaultActionTitle: String {
            ActionCatalog.title(for: defaultActionId)
        }
    }

    // MARK: - Slot IDs

    enum ID {
        static let mmLeft = "mouse.surface.1.tap.left"
        static let mmRight = "mouse.surface.1.tap.right"
        static let mmMiddle2 = "mouse.surface.2.touch.middle"
        static let mmMiddle3 = "mouse.surface.3.touch.middle"
        static let mmDrag = "mouse.surface.1.doubleTapHold.drag"
        static let mm2fDoubleMC = "mouse.surface.2.doubleTap.missionControl"
        static let mm2fSwipeUp = "mouse.surface.2.swipe.up"
        static let mm2fSwipeDown = "mouse.surface.2.swipe.down"
        static let mm2fSwipeLeft = "mouse.surface.2.swipe.left"
        static let mm2fSwipeRight = "mouse.surface.2.swipe.right"
        static let mm3fSwipeLeft = "mouse.surface.3.swipe.left"
        static let mm3fSwipeRight = "mouse.surface.3.swipe.right"
        static let mm3fSwipeUp = "mouse.surface.3.swipe.up"
        static let mm3fSwipeDown = "mouse.surface.3.swipe.down"
        static let mm2fTopEdgeMove = "mouse.surface.2.topEdge.dragMove"
        static let mm3fTopEdgeResize = "mouse.surface.3.topEdge.dragResize"
        static let mm1fSwipeLeft = "mouse.surface.1.swipe.left"
        static let mm1fSwipeRight = "mouse.surface.1.swipe.right"
        // Finger count stays 2 so `GestureDiagram.from(slotId:)` draws both contacts.
        static let mmTipTapLeft = "mouse.surface.2.tipTap.left"
        static let mmTipTapRight = "mouse.surface.2.tipTap.right"
        static let mmTipTapMiddle = "mouse.surface.2.tipTap.middle"

        static let tbLeft = "trackpad.titlebar.2.swipe.left"
        static let tbRight = "trackpad.titlebar.2.swipe.right"
        static let tbLeftLong = "trackpad.titlebar.2.swipe.left.long"
        static let tbRightLong = "trackpad.titlebar.2.swipe.right.long"
        static let tbUp = "trackpad.titlebar.2.swipe.up"
        static let tbUpLong = "trackpad.titlebar.2.swipe.up.long"
        static let tbDown = "trackpad.titlebar.2.swipe.down"
        static let tbUpLeft = "trackpad.titlebar.2.swipe.upLeft"
        static let tbUpRight = "trackpad.titlebar.2.swipe.upRight"
        static let tbDownLeft = "trackpad.titlebar.2.swipe.downLeft"
        static let tbDownRight = "trackpad.titlebar.2.swipe.downRight"
        static let tbPinchIn = "trackpad.titlebar.2.pinch.in"
        static let tbPinchOut = "trackpad.titlebar.2.pinch.out"
        static let tb3Left = "trackpad.titlebar.3.swipe.left"
        static let tb3Right = "trackpad.titlebar.3.swipe.right"

        static let dockUp = "trackpad.dock.2.swipe.up"
        static let dockDown = "trackpad.dock.2.swipe.down"
        static let dockPinchIn = "trackpad.dock.2.pinch.in"
        static let dockPinchOut = "trackpad.dock.2.pinch.out"

        static let mbLeft = "trackpad.menubar.2.swipe.left"
        static let mbRight = "trackpad.menubar.2.swipe.right"
        static let mbDown = "trackpad.menubar.2.swipe.down"
        static let mbUp = "trackpad.menubar.2.swipe.up"

        static let free3Tap = "trackpad.free.3.tap"
        static let free3Drag = "trackpad.free.3.drag"
        static let free3SwipeLeft = "trackpad.free.3.swipe.left"
        static let free3SwipeRight = "trackpad.free.3.swipe.right"
        static let free3SwipeUp = "trackpad.free.3.swipe.up"
        static let free3SwipeDown = "trackpad.free.3.swipe.down"
        static let free4SwipeLeft = "trackpad.free.4.swipe.left"
        static let free4SwipeRight = "trackpad.free.4.swipe.right"
        static let free4SwipeUp = "trackpad.free.4.swipe.up"
        static let free4SwipeDown = "trackpad.free.4.swipe.down"
        static let free4Tap = "trackpad.free.4.tap"
        // Finger count stays 2 so `GestureDiagram.from(slotId:)` draws both contacts.
        static let tipTapLeft = "trackpad.free.2.tipTap.left"
        static let tipTapRight = "trackpad.free.2.tipTap.right"
        static let tipTapMiddle = "trackpad.free.2.tipTap.middle"
        static let tipTap3Left = "trackpad.free.3.tipTap.left"
        static let tipTap3Right = "trackpad.free.3.tipTap.right"
        static let tipTap3Middle = "trackpad.free.3.tipTap.middle"
        static let free3Click = "trackpad.free.3.click"
        static let cornerTopLeft = "trackpad.free.1.tap.topLeft"
        static let cornerTopRight = "trackpad.free.1.tap.topRight"
        static let cornerBottomLeft = "trackpad.free.1.tap.bottomLeft"
        static let cornerBottomRight = "trackpad.free.1.tap.bottomRight"
        static let tapTop = "trackpad.free.1.tap.top"

        static let kbLeft = "keyboard.chord.left"
        static let kbRight = "keyboard.chord.right"
        static let kbUp = "keyboard.chord.up"
        static let kbDown = "keyboard.chord.down"
        static let kbReturn = "keyboard.chord.return"
        static let kbDisplayLeft = "keyboard.chord.displayLeft"
        static let kbDisplayRight = "keyboard.chord.displayRight"
    }

    static let all: [Slot] = [
        // Magic Mouse
        .init(id: ID.mmLeft, group: .magicMouse, title: "Tap left", detail: "Surface left zone",
              defaultActionId: ActionCatalog.ID.clickLeft, legacyGate: .mmLeftTap, actionFixed: false, visibility: .simple),
        .init(id: ID.mmRight, group: .magicMouse, title: "Tap right", detail: "Surface right zone",
              defaultActionId: ActionCatalog.ID.clickRight, legacyGate: .mmRightTap, actionFixed: false, visibility: .simple),
        // Natural macOS mapping: finger right → back, finger left → forward (content follows finger).
        .init(id: ID.mm1fSwipeLeft, group: .magicMouse, title: "1-finger swipe left", detail: "Forward / next page",
              defaultActionId: ActionCatalog.ID.browserForward, legacyGate: .mmOneFingerSwipePages, actionFixed: false, visibility: .simple),
        .init(id: ID.mm1fSwipeRight, group: .magicMouse, title: "1-finger swipe right", detail: "Back / previous page",
              defaultActionId: ActionCatalog.ID.browserBack, legacyGate: .mmOneFingerSwipePages, actionFixed: false, visibility: .simple),
        .init(id: ID.mmMiddle2, group: .magicMouse, title: "2-finger touch", detail: "Short multi-touch",
              defaultActionId: ActionCatalog.ID.clickMiddle, legacyGate: .mmMiddleTwo, actionFixed: false),
        .init(id: ID.mmMiddle3, group: .magicMouse, title: "3-finger touch", detail: "Multi-touch",
              defaultActionId: ActionCatalog.ID.clickMiddle, legacyGate: .mmMiddleThree, actionFixed: false, visibility: .simple),
        .init(id: ID.mmDrag, group: .magicMouse, title: "Double-tap hold", detail: "Tap-drag",
              defaultActionId: ActionCatalog.ID.drag, legacyGate: .mmTapDrag, actionFixed: false, visibility: .simple),
        .init(id: ID.mm2fDoubleMC, group: .magicMouse, title: "2-finger double-tap", detail: "Mission Control",
              defaultActionId: ActionCatalog.ID.missionControl, legacyGate: .mmTwoFingerDoubleMC, actionFixed: false),
        .init(id: ID.mm2fSwipeUp, group: .magicMouse, title: "2-finger swipe up", detail: "",
              defaultActionId: ActionCatalog.ID.missionControl, legacyGate: .mmTwoFingerSwipeUp, actionFixed: false),
        .init(id: ID.mm2fSwipeDown, group: .magicMouse, title: "2-finger swipe down", detail: "",
              defaultActionId: ActionCatalog.ID.appExpose, legacyGate: .mmTwoFingerSwipeDown, actionFixed: false),
        .init(id: ID.mm2fSwipeLeft, group: .magicMouse, title: "2-finger swipe left", detail: "Spaces (off by default)",
              defaultActionId: ActionCatalog.ID.spaceLeft, legacyGate: .mmTwoFingerSpaces, actionFixed: false, defaultEnabled: false),
        .init(id: ID.mm2fSwipeRight, group: .magicMouse, title: "2-finger swipe right", detail: "Spaces (off by default)",
              defaultActionId: ActionCatalog.ID.spaceRight, legacyGate: .mmTwoFingerSpaces, actionFixed: false, defaultEnabled: false),
        // BTT factory default: rest one finger, tap the other. Positional, so tap left →
        // previous tab. Distinguished from 2-finger middle-click by requiring the first
        // finger to sit still before the second lands.
        .init(id: ID.mmTipTapLeft, group: .magicMouse, title: "Tip-tap left", detail: "Hold a finger, tap to its left",
              defaultActionId: ActionCatalog.ID.browserPrevTab, legacyGate: .mmTipTap, actionFixed: false, visibility: .simple),
        .init(id: ID.mmTipTapRight, group: .magicMouse, title: "Tip-tap right", detail: "Hold a finger, tap to its right",
              defaultActionId: ActionCatalog.ID.browserNextTab, legacyGate: .mmTipTap, actionFixed: false, visibility: .simple),
        .init(id: ID.mmTipTapMiddle, group: .magicMouse, title: "Tip-tap middle", detail: "Hold a finger, tap near it (off by default)",
              defaultActionId: ActionCatalog.ID.browserCloseTab, legacyGate: .mmTipTapMiddle, actionFixed: false, defaultEnabled: false),
        // 3-finger swipes share the chord with the 3-finger middle-click above; travel decides
        // which fires. Tabs on L/R follows the same spatial mapping as the free-space 4-finger
        // swipes and tip-tap (tap/swipe left → go left) rather than content-follows-finger.
        .init(id: ID.mm3fSwipeLeft, group: .magicMouse, title: "3-finger swipe left", detail: "Previous tab (off by default)",
              defaultActionId: ActionCatalog.ID.browserPrevTab, legacyGate: .mmThreeFingerSwipes, actionFixed: false, defaultEnabled: false),
        .init(id: ID.mm3fSwipeRight, group: .magicMouse, title: "3-finger swipe right", detail: "Next tab (off by default)",
              defaultActionId: ActionCatalog.ID.browserNextTab, legacyGate: .mmThreeFingerSwipes, actionFixed: false, defaultEnabled: false),
        .init(id: ID.mm3fSwipeUp, group: .magicMouse, title: "3-finger swipe up", detail: "Mission Control (off by default)",
              defaultActionId: ActionCatalog.ID.missionControl, legacyGate: .mmThreeFingerSwipes, actionFixed: false, defaultEnabled: false),
        .init(id: ID.mm3fSwipeDown, group: .magicMouse, title: "3-finger swipe down", detail: "App Exposé (off by default)",
              defaultActionId: ActionCatalog.ID.appExpose, legacyGate: .mmThreeFingerSwipes, actionFixed: false, defaultEnabled: false),
        .init(id: ID.mm2fTopEdgeMove, group: .magicMouse, title: "2-finger top-edge drag", detail: "Move window under cursor",
              defaultActionId: ActionCatalog.ID.moveWindow, legacyGate: .mmTwoFingerTopEdgeMove, actionFixed: true),
        .init(id: ID.mm3fTopEdgeResize, group: .magicMouse, title: "3-finger top-edge drag", detail: "Resize window under cursor",
              defaultActionId: ActionCatalog.ID.resizeWindow, legacyGate: .mmThreeFingerTopEdgeResize, actionFixed: true),

        // Titlebar
        .init(id: ID.tbLeft, group: .titlebar, title: "Swipe left", detail: "2 fingers · short",
              defaultActionId: ActionCatalog.ID.snapLeftHalf, legacyGate: .tbHalves, actionFixed: false, visibility: .simple),
        .init(id: ID.tbRight, group: .titlebar, title: "Swipe right", detail: "2 fingers · short",
              defaultActionId: ActionCatalog.ID.snapRightHalf, legacyGate: .tbHalves, actionFixed: false, visibility: .simple),
        .init(id: ID.tbLeftLong, group: .titlebar, title: "Long swipe left", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapLeftThird, legacyGate: .tbThirds, actionFixed: false),
        .init(id: ID.tbRightLong, group: .titlebar, title: "Long swipe right", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapRightThird, legacyGate: .tbThirds, actionFixed: false),
        .init(id: ID.tbUp, group: .titlebar, title: "Swipe up", detail: "2 fingers · short",
              defaultActionId: ActionCatalog.ID.snapMaximize, legacyGate: .tbMaximize, actionFixed: false, visibility: .simple),
        .init(id: ID.tbUpLong, group: .titlebar, title: "Long swipe up", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapCenterLarge, legacyGate: .tbMaximize, actionFixed: false),
        .init(id: ID.tbDown, group: .titlebar, title: "Swipe down", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.minimize, legacyGate: .tbMinimize, actionFixed: false, visibility: .simple),
        .init(id: ID.tbUpLeft, group: .titlebar, title: "Diagonal up-left", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapTopLeft, legacyGate: .tbQuarters, actionFixed: false),
        .init(id: ID.tbUpRight, group: .titlebar, title: "Diagonal up-right", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapTopRight, legacyGate: .tbQuarters, actionFixed: false),
        .init(id: ID.tbDownLeft, group: .titlebar, title: "Diagonal down-left", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapBottomLeft, legacyGate: .tbQuarters, actionFixed: false),
        .init(id: ID.tbDownRight, group: .titlebar, title: "Diagonal down-right", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.snapBottomRight, legacyGate: .tbQuarters, actionFixed: false),
        .init(id: ID.tbPinchIn, group: .titlebar, title: "Pinch in", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.close, legacyGate: .tbPinchClose, actionFixed: false, visibility: .simple),
        .init(id: ID.tbPinchOut, group: .titlebar, title: "Pinch out", detail: "2 fingers",
              defaultActionId: ActionCatalog.ID.fullscreen, legacyGate: .tbPinchFullscreen, actionFixed: false, visibility: .simple),
        .init(id: ID.tb3Left, group: .titlebar, title: "3-finger swipe left", detail: "Adjacent display",
              defaultActionId: ActionCatalog.ID.moveDisplayLeft, legacyGate: .tbThreeFingerDisplay, actionFixed: false),
        .init(id: ID.tb3Right, group: .titlebar, title: "3-finger swipe right", detail: "Adjacent display",
              defaultActionId: ActionCatalog.ID.moveDisplayRight, legacyGate: .tbThreeFingerDisplay, actionFixed: false),

        // Dock
        .init(id: ID.dockUp, group: .dock, title: "Swipe up", detail: "On Dock icon",
              defaultActionId: ActionCatalog.ID.dockActivate, legacyGate: .dockActivate, actionFixed: false, visibility: .simple),
        .init(id: ID.dockDown, group: .dock, title: "Swipe down", detail: "On Dock icon",
              defaultActionId: ActionCatalog.ID.dockHide, legacyGate: .dockHide, actionFixed: false, visibility: .simple),
        .init(id: ID.dockPinchOut, group: .dock, title: "Pinch out", detail: "On Dock icon",
              defaultActionId: ActionCatalog.ID.dockNewWindow, legacyGate: .dockNew, actionFixed: false, visibility: .simple),
        .init(id: ID.dockPinchIn, group: .dock, title: "Pinch in", detail: "On Dock icon (off by default)",
              defaultActionId: ActionCatalog.ID.dockQuit, legacyGate: .dockQuit, actionFixed: false, defaultEnabled: false),

        // Menubar
        .init(id: ID.mbLeft, group: .menubar, title: "Swipe left", detail: "Menu bar band",
              defaultActionId: ActionCatalog.ID.menubarPrev, legacyGate: .mbCycle, actionFixed: false, visibility: .simple),
        .init(id: ID.mbRight, group: .menubar, title: "Swipe right", detail: "Menu bar band",
              defaultActionId: ActionCatalog.ID.menubarNext, legacyGate: .mbCycle, actionFixed: false, visibility: .simple),
        .init(id: ID.mbDown, group: .menubar, title: "Swipe down", detail: "Menu bar band",
              defaultActionId: ActionCatalog.ID.menubarHideOthers, legacyGate: .mbHideOthers, actionFixed: false),
        .init(id: ID.mbUp, group: .menubar, title: "Swipe up", detail: "Menu bar band",
              defaultActionId: ActionCatalog.ID.menubarUnminimize, legacyGate: .mbUnminimize, actionFixed: false),

        // Free trackpad
        .init(id: ID.free3Tap, group: .trackpad, title: "3-finger tap", detail: "Free space",
              defaultActionId: ActionCatalog.ID.clickMiddle, legacyGate: .trackpadMiddle, actionFixed: false, visibility: .simple),
        .init(id: ID.free3Drag, group: .trackpad, title: "3-finger drag", detail: "Free space · text select / drag",
              defaultActionId: ActionCatalog.ID.drag, legacyGate: .trackpadThreeFingerDrag, actionFixed: true, visibility: .simple),

        // Free trackpad — 3-finger swipes (off by default; macOS also uses these).
        // Same natural direction as the Magic Mouse page swipes above: content follows the
        // fingers, so moving left reveals the next page (forward).
        .init(id: ID.free3SwipeLeft, group: .trackpad, title: "3-finger swipe left", detail: "Forward (off by default)",
              defaultActionId: ActionCatalog.ID.browserForward, legacyGate: .trackpadFreeThreeSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free3SwipeRight, group: .trackpad, title: "3-finger swipe right", detail: "Back (off by default)",
              defaultActionId: ActionCatalog.ID.browserBack, legacyGate: .trackpadFreeThreeSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free3SwipeUp, group: .trackpad, title: "3-finger swipe up", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.snapMaximize, legacyGate: .trackpadFreeThreeSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free3SwipeDown, group: .trackpad, title: "3-finger swipe down", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.minimize, legacyGate: .trackpadFreeThreeSwipe, actionFixed: false, defaultEnabled: false),

        // Free trackpad — 4-finger swipes (off by default; macOS also uses these).
        .init(id: ID.free4SwipeLeft, group: .trackpad, title: "4-finger swipe left", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.browserPrevTab, legacyGate: .trackpadFreeFourSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free4SwipeRight, group: .trackpad, title: "4-finger swipe right", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.browserNextTab, legacyGate: .trackpadFreeFourSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free4SwipeUp, group: .trackpad, title: "4-finger swipe up", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.missionControl, legacyGate: .trackpadFreeFourSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free4SwipeDown, group: .trackpad, title: "4-finger swipe down", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.appExpose, legacyGate: .trackpadFreeFourSwipe, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free4Tap, group: .trackpad, title: "4-finger tap", detail: "Free space (off by default)",
              defaultActionId: ActionCatalog.ID.keySpotlight, legacyGate: .trackpadFreeFourTap, actionFixed: false, defaultEnabled: false),

        // Free trackpad — tip-tap (hold one finger, tap a second beside it). Positional, not
        // directional, so the side maps straight through: tap left → go left. Same BTT factory
        // mapping as Magic Mouse tip-tap. A simultaneous two-finger scroll lands both fingers
        // together and never arms, so this can stay on next to scrolling.
        .init(id: ID.tipTapLeft, group: .trackpad, title: "Tip-tap left", detail: "Hold a finger, tap to its left",
              defaultActionId: ActionCatalog.ID.browserPrevTab, legacyGate: .trackpadTipTap, actionFixed: false, visibility: .simple),
        .init(id: ID.tipTapRight, group: .trackpad, title: "Tip-tap right", detail: "Hold a finger, tap to its right",
              defaultActionId: ActionCatalog.ID.browserNextTab, legacyGate: .trackpadTipTap, actionFixed: false, visibility: .simple),
        .init(id: ID.tipTapMiddle, group: .trackpad, title: "Tip-tap middle", detail: "Hold a finger, tap near it (off by default)",
              defaultActionId: ActionCatalog.ID.browserCloseTab, legacyGate: .trackpadTipTapMiddle, actionFixed: false, defaultEnabled: false),
        .init(id: ID.tipTap3Left, group: .trackpad, title: "3-finger tip-tap left", detail: "Hold two fingers, tap to their left (off by default)",
              defaultActionId: ActionCatalog.ID.browserPrevTab, legacyGate: .trackpadThreeFingerTipTap, actionFixed: false, defaultEnabled: false),
        .init(id: ID.tipTap3Right, group: .trackpad, title: "3-finger tip-tap right", detail: "Hold two fingers, tap to their right (off by default)",
              defaultActionId: ActionCatalog.ID.browserNextTab, legacyGate: .trackpadThreeFingerTipTap, actionFixed: false, defaultEnabled: false),
        .init(id: ID.tipTap3Middle, group: .trackpad, title: "3-finger tip-tap middle", detail: "Hold two fingers, tap near them (off by default)",
              defaultActionId: ActionCatalog.ID.browserCloseTab, legacyGate: .trackpadThreeFingerTipTap, actionFixed: false, defaultEnabled: false),
        .init(id: ID.free3Click, group: .trackpad, title: "3-finger click", detail: "Physical click with three fingers (off by default)",
              defaultActionId: ActionCatalog.ID.clickMiddle, legacyGate: .trackpadThreeFingerClick, actionFixed: false, defaultEnabled: false),
        .init(id: ID.cornerTopLeft, group: .trackpad, title: "Tap top-left", detail: "Corner (off by default)",
              defaultActionId: ActionCatalog.ID.missionControl, legacyGate: .trackpadCornerTaps, actionFixed: false, defaultEnabled: false),
        .init(id: ID.cornerTopRight, group: .trackpad, title: "Tap top-right", detail: "Corner (off by default)",
              defaultActionId: ActionCatalog.ID.appExpose, legacyGate: .trackpadCornerTaps, actionFixed: false, defaultEnabled: false),
        .init(id: ID.cornerBottomLeft, group: .trackpad, title: "Tap bottom-left", detail: "Corner (off by default)",
              defaultActionId: ActionCatalog.ID.spaceLeft, legacyGate: .trackpadCornerTaps, actionFixed: false, defaultEnabled: false),
        .init(id: ID.cornerBottomRight, group: .trackpad, title: "Tap bottom-right", detail: "Corner (off by default)",
              defaultActionId: ActionCatalog.ID.spaceRight, legacyGate: .trackpadCornerTaps, actionFixed: false, defaultEnabled: false),
        .init(id: ID.tapTop, group: .trackpad, title: "Tap top edge", detail: "Top band (off by default)",
              defaultActionId: ActionCatalog.ID.keySpotlight, legacyGate: .trackpadCornerTaps, actionFixed: false, defaultEnabled: false),

        // Keyboard — ⌃⌥ chord. ↓ restores (titlebar ↓ stays minimize). Repeat ←/→ still
        // cycles thirds when that Keyboard page option is on.
        .init(id: ID.kbLeft, group: .keyboard, title: "⌃⌥ ←", detail: "Left half; repeat cycles thirds",
              defaultActionId: ActionCatalog.ID.snapLeftHalf, legacyGate: .keyboardSnap, actionFixed: false, visibility: .simple),
        .init(id: ID.kbRight, group: .keyboard, title: "⌃⌥ →", detail: "Right half; repeat cycles thirds",
              defaultActionId: ActionCatalog.ID.snapRightHalf, legacyGate: .keyboardSnap, actionFixed: false, visibility: .simple),
        .init(id: ID.kbUp, group: .keyboard, title: "⌃⌥ ↑", detail: "Maximize",
              defaultActionId: ActionCatalog.ID.snapMaximize, legacyGate: .keyboardSnap, actionFixed: false, visibility: .simple),
        .init(id: ID.kbDown, group: .keyboard, title: "⌃⌥ ↓", detail: "Restore previous frame",
              defaultActionId: ActionCatalog.ID.restore, legacyGate: .keyboardSnap, actionFixed: false, visibility: .simple),
        .init(id: ID.kbReturn, group: .keyboard, title: "⌃⌥ ↩", detail: "Large center",
              defaultActionId: ActionCatalog.ID.snapCenterLarge, legacyGate: .keyboardSnap, actionFixed: false, visibility: .simple),
        .init(id: ID.kbDisplayLeft, group: .keyboard, title: "⌃⌥⌘ ←", detail: "Adjacent display",
              defaultActionId: ActionCatalog.ID.moveDisplayLeft, legacyGate: .keyboardDisplay, actionFixed: false, visibility: .simple),
        .init(id: ID.kbDisplayRight, group: .keyboard, title: "⌃⌥⌘ →", detail: "Adjacent display",
              defaultActionId: ActionCatalog.ID.moveDisplayRight, legacyGate: .keyboardDisplay, actionFixed: false, visibility: .simple),
    ]

    private static let byId: [String: Slot] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static func slot(id: String) -> Slot? { byId[id] }

    static let longSwipeMagnitude: CGFloat = 0.22

    // MARK: - Slot lookup helpers

    static func titlebarSwipeSlot(fingers: Int, direction: SwipeDirection, magnitude: CGFloat) -> String? {
        titlebarSwipeSlot(fingers: fingers, direction: direction, magnitude: magnitude, cycleThirds: false)
    }

    /// When `cycleThirds` is on, left/right 2-finger swipes stay on the short slot;
    /// magnitude picks the layout in `LayoutGeometry.continuous*Layout`.
    static func titlebarSwipeSlot(
        fingers: Int,
        direction: SwipeDirection,
        magnitude: CGFloat,
        cycleThirds: Bool
    ) -> String? {
        if fingers >= 3 {
            switch direction {
            case .left: return ID.tb3Left
            case .right: return ID.tb3Right
            default: return nil
            }
        }
        let long = magnitude >= longSwipeMagnitude
        switch direction {
        case .left: return (cycleThirds || !long) ? ID.tbLeft : ID.tbLeftLong
        case .right: return (cycleThirds || !long) ? ID.tbRight : ID.tbRightLong
        case .up: return long ? ID.tbUpLong : ID.tbUp
        case .down: return ID.tbDown
        case .upLeft: return ID.tbUpLeft
        case .upRight: return ID.tbUpRight
        case .downLeft: return ID.tbDownLeft
        case .downRight: return ID.tbDownRight
        }
    }

    static func titlebarPinchSlot(inward: Bool) -> String {
        inward ? ID.tbPinchIn : ID.tbPinchOut
    }

    static func dockSwipeSlot(direction: SwipeDirection) -> String? {
        switch direction {
        case .up: return ID.dockUp
        case .down: return ID.dockDown
        default: return nil
        }
    }

    static func dockPinchSlot(inward: Bool) -> String {
        inward ? ID.dockPinchIn : ID.dockPinchOut
    }

    static func menubarSwipeSlot(direction: SwipeDirection) -> String? {
        switch direction {
        case .left: return ID.mbLeft
        case .right: return ID.mbRight
        case .down: return ID.mbDown
        case .up: return ID.mbUp
        default: return nil
        }
    }

    /// Free-space swipe slot for a locked finger count. 5+ contacts (thumb resting) map to
    /// the 4-finger row; free space has no diagonal slots.
    static func freeSwipeSlot(fingers: Int, direction: SwipeDirection) -> String? {
        switch (fingers >= 4, direction) {
        case (false, .left): return ID.free3SwipeLeft
        case (false, .right): return ID.free3SwipeRight
        case (false, .up): return ID.free3SwipeUp
        case (false, .down): return ID.free3SwipeDown
        case (true, .left): return ID.free4SwipeLeft
        case (true, .right): return ID.free4SwipeRight
        case (true, .up): return ID.free4SwipeUp
        case (true, .down): return ID.free4SwipeDown
        default: return nil
        }
    }

    static func tipTapSlot(side: TipTapRecognizer.Side, fingers: Int = 2) -> String {
        if fingers >= 3 {
            switch side {
            case .left: return ID.tipTap3Left
            case .right: return ID.tipTap3Right
            case .middle: return ID.tipTap3Middle
            }
        }
        switch side {
        case .left: return ID.tipTapLeft
        case .right: return ID.tipTapRight
        case .middle: return ID.tipTapMiddle
        }
    }

    static func magicMouseTipTapSlot(side: TipTapRecognizer.Side) -> String {
        switch side {
        case .left: return ID.mmTipTapLeft
        case .right: return ID.mmTipTapRight
        case .middle: return ID.mmTipTapMiddle
        }
    }

    /// Master section switch for a slot group.
    static func masterEnabled(group: Group, config: SanneConfig) -> Bool {
        switch group {
        case .magicMouse: return config.magicMouseTaps.enabled
        case .titlebar: return config.titlebarGestures.enabled
        case .dock: return config.dockGestures.enabled
        case .menubar: return config.menubarGestures.enabled
        case .trackpad: return true
        case .keyboard: return config.keyboard.enabled
        }
    }

    static func defaultEnabled(for slot: Slot) -> Bool { slot.defaultEnabled }

    static func defaultEnabled(for gate: LegacyGate) -> Bool {
        switch gate {
        case .mmTwoFingerSpaces, .mmThreeFingerSwipes, .mmTipTapMiddle, .dockQuit,
             .trackpadFreeThreeSwipe, .trackpadFreeFourSwipe, .trackpadFreeFourTap,
             .trackpadTipTapMiddle, .trackpadThreeFingerTipTap, .trackpadThreeFingerClick,
             .trackpadCornerTaps:
            return false
        default:
            return true
        }
    }

    static func legacyEnabled(_ gate: LegacyGate, config: SanneConfig) -> Bool {
        let mm = config.magicMouseTaps
        let tb = config.titlebarGestures
        let dg = config.dockGestures
        let mb = config.menubarGestures
        switch gate {
        case .magicMouseMaster: return mm.enabled
        case .mmLeftTap: return mm.leftTap
        case .mmRightTap: return mm.rightTap
        case .mmMiddleTwo: return mm.middleTwoFinger
        case .mmMiddleThree: return mm.middleThreeFinger
        case .mmMultiClick: return mm.multiClick
        case .mmTapDrag: return mm.tapDrag
        case .mmTwoFingerDoubleMC: return mm.twoFingerDoubleTapMissionControl
        case .mmTwoFingerSwipeUp: return mm.twoFingerSwipeUpMissionControl
        case .mmTwoFingerSwipeDown: return mm.twoFingerSwipeDownAppExpose
        case .mmTwoFingerSpaces: return mm.twoFingerSwipeSpaces
        case .mmThreeFingerSwipes: return mm.threeFingerSwipes
        case .mmTwoFingerTopEdgeMove: return mm.twoFingerTopEdgeMove
        case .mmThreeFingerTopEdgeResize: return true
        case .mmOneFingerSwipePages: return mm.oneFingerSwipePages
        case .mmTipTap: return true
        case .mmTipTapMiddle: return false
        case .titlebarMaster: return tb.enabled
        case .tbHalves: return tb.swipeHalves
        case .tbThirds: return tb.swipeThirds
        case .tbQuarters: return tb.swipeQuarters
        case .tbMaximize: return tb.swipeMaximize
        case .tbMinimize: return tb.swipeMinimize
        case .tbPinchClose: return tb.pinchClose
        case .tbPinchFullscreen: return tb.pinchFullscreen
        case .tbThreeFingerDisplay: return tb.threeFingerMoveDisplay
        case .dockMaster: return dg.enabled
        case .dockActivate: return dg.swipeActivate
        case .dockHide: return dg.swipeHide
        case .dockNew: return dg.pinchNewWindow
        case .dockQuit: return dg.pinchQuit
        case .menubarMaster: return mb.enabled
        case .mbCycle: return mb.swipeCycleWindows
        case .mbHideOthers: return mb.swipeHideOthers
        case .mbUnminimize: return mb.swipeUnminimize
        case .trackpadMiddle: return config.trackpad.threeFingerTapMiddleClick
        case .trackpadThreeFingerDrag: return config.trackpad.threeFingerDrag
        case .trackpadFreeThreeSwipe: return config.trackpad.threeFingerSwipes
        case .trackpadFreeFourSwipe: return config.trackpad.fourFingerSwipes
        case .trackpadFreeFourTap: return config.trackpad.fourFingerTap
        case .trackpadTipTap: return config.trackpad.tipTap
        case .trackpadTipTapMiddle: return false
        case .trackpadThreeFingerTipTap: return false
        case .trackpadThreeFingerClick: return false
        case .trackpadCornerTaps: return false
        case .keyboardSnap: return config.keyboard.snapWithArrows
        case .keyboardDisplay: return config.keyboard.moveToAdjacentDisplay
        }
    }
}
