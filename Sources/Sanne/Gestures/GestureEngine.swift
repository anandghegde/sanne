import AppKit
import ApplicationServices
import Foundation

/// Per-touch-session context (zone, window, dock app, peak fingers, frontmost app, pinch).
private struct GestureSession {
    var zone: CursorZone = .free
    var window: AXUIElement?
    var dockApp: NSRunningApplication?
    var peakFingers = 0
    var frontmostBundle: String?
    var pinchCandidate: Bool?
    var dragBegan = false
    var loggedPreviewLayout: WindowLayout?
    var snapshot = RuntimeSnapshot.empty
}

private struct SessionBegin {
    var zone: CursorZone
    var window: AXUIElement?
    var dockApp: NSRunningApplication?
    var frontmostBundle: String?
    var snapshot: RuntimeSnapshot
    var point: CGPoint
}

/// Trackpad zone gestures (titlebar / Dock / menubar). Magic Mouse taps: `MagicMouseTapController`.
final class GestureEngine: @unchecked Sendable {
    static let shared = GestureEngine()

    private let pipeline = TouchDeviceManager.shared.pipelineQueue
    private let swipePinch = SwipePinchRecognizer()
    private let threeFingerDrag = ThreeFingerDragRecognizer()
    private let fourFingerTap = ThreeFingerDragRecognizer()
    private let tipTap = TipTapRecognizer()
    private var listenerID: UUID?

    private var session = GestureSession()
    private var hadTouches = false
    private var awaitingBegin = false
    private var sessionReady = false
    private var pendingFrames: [TouchFrame] = []

    private var isPaused: () -> Bool = { false }
    private var isMagicMousePaused: () -> Bool = { false }

    func start(
        config: @escaping () -> SanneConfig,
        paused: @escaping () -> Bool,
        magicMousePaused: (() -> Bool)? = nil
    ) {
        _ = config
        isPaused = paused
        isMagicMousePaused = magicMousePaused ?? paused

        MagicMouseTapController.shared.start { event in
            MainHop.async {
                GestureEngine.shared.handleMagicMouse(event)
            }
        }

        guard listenerID == nil else { return }
        listenerID = TouchDeviceManager.shared.addListener { [weak self] frame in
            self?.handle(frame)
        }
        Log.info(.gesture, "GestureEngine started (titlebar + Dock + menubar + Magic Mouse taps)")
    }

    func stop() {
        MainHop.async { HUDController.shared.hide() }
        MagicMouseTapController.shared.stop()
        if let listenerID {
            TouchDeviceManager.shared.removeListener(listenerID)
        }
        listenerID = nil
        if threeFingerDrag.isDragging {
            ClickEmitter.mouseUp(.left)
        }
        threeFingerDrag.reset()
        fourFingerTap.reset()
        swipePinch.reset()
        tipTap.reset()
        session = GestureSession()
        awaitingBegin = false
        sessionReady = false
        pendingFrames = []
        hadTouches = false
    }

    // MARK: - Magic Mouse

    @MainActor
    private func handleMagicMouse(_ event: MagicMouseEvent) {
        if isMagicMousePaused() { return }
        let snap = RuntimeSnapshotStore.shared.snapshot
        switch event {
        case .recognized(let slotId, let clickCount):
            guard snap.slotOn(slotId), let actionId = snap.actionId(for: slotId) else {
                Log.debug(.gesture, "MagicMouse slot=\(slotId) disabled")
                return
            }
            Log.info(.gesture, "MagicMouse slot=\(slotId) → \(actionId)×\(clickCount)")
            GestureActivity.announce(slotId: slotId)
            var ctx = ActionContext(
                window: session.window,
                dockApp: session.dockApp,
                gap: CGFloat(snap.gap),
                haptics: snap.haptics
            )
            if actionId == ActionCatalog.ID.clickLeft {
                ctx.clickCount = snap.multiClick ? clickCount : 1
            }
            _ = perform(actionId, context: ctx, hudEnabled: snap.hudEnabled)
            if slotId == GestureSlots.ID.mmLeft || actionId == ActionCatalog.ID.clickLeft {
                TutorialPrefs.post(.magicMouseClick)
            }
            if actionId == ActionCatalog.ID.clickMiddle {
                TutorialPrefs.post(.trackpadMiddleClick)
            }
        }
    }

    // MARK: - Trackpad frames (pipeline queue)

    private func handle(_ frame: TouchFrame) {
        if isPaused() {
            if threeFingerDrag.isDragging {
                ClickEmitter.mouseUp(.left)
                threeFingerDrag.reset()
            }
            swipePinch.reset()
            tipTap.reset()
            fourFingerTap.reset()
            session = GestureSession()
            awaitingBegin = false
            sessionReady = false
            pendingFrames = []
            hadTouches = false
            return
        }

        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }

        if awaitingBegin {
            pendingFrames.append(frame)
            return
        }

        if !sessionReady, !live.isEmpty {
            awaitingBegin = true
            pendingFrames = [frame]
            MainHop.async {
                let begin = GestureEngine.sampleBegin()
                TouchDeviceManager.shared.pipelineQueue.async {
                    GestureEngine.shared.applyBegin(begin)
                }
            }
            return
        }

        process(frame)
    }

    @MainActor
    private static func sampleBegin() -> SessionBegin {
        let point = NSEvent.mouseLocation
        let snap = RuntimeSnapshotStore.shared.snapshot
        let zone = ZoneClassifier.zone(at: point)
        var window: AXUIElement?
        var dockApp: NSRunningApplication?
        switch zone {
        case .titlebar:
            window = WindowManager.shared.windowAt(appKitPoint: point)
        case .dock:
            dockApp = ZoneActions.dockApp(at: point)
        default:
            break
        }
        return SessionBegin(
            zone: zone,
            window: window,
            dockApp: dockApp,
            frontmostBundle: snap.frontmostBundleId,
            snapshot: snap,
            point: point
        )
    }

    private func applyBegin(_ begin: SessionBegin) {
        awaitingBegin = false
        sessionReady = true
        session = GestureSession(
            zone: begin.zone,
            window: begin.window,
            dockApp: begin.dockApp,
            frontmostBundle: begin.frontmostBundle,
            snapshot: begin.snapshot
        )
        switch begin.zone {
        case .titlebar:
            Log.info(
                .gesture,
                "gesture begin zone=titlebar " +
                "window=\(begin.window != nil ? "yes" : "nil") " +
                "cursor=(\(Int(begin.point.x)),\(Int(begin.point.y)))"
            )
        case .dock:
            Log.info(
                .gesture,
                "gesture begin zone=dock " +
                "app=\(begin.dockApp?.localizedName ?? "nil") " +
                "cursor=(\(Int(begin.point.x)),\(Int(begin.point.y)))"
            )
        case .menubar:
            Log.info(
                .gesture,
                "gesture begin zone=menubar " +
                "cursor=(\(Int(begin.point.x)),\(Int(begin.point.y)))"
            )
        case .free:
            break
        }
        let frames = pendingFrames
        pendingFrames = []
        for frame in frames {
            process(frame)
        }
    }

    private func process(_ frame: TouchFrame) {
        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        hadTouches = !live.isEmpty
        let snap = session.snapshot

        if session.zone == .free {
            handleFreeSpace(frame: frame, fingers: live.count, snap: snap)
            if live.isEmpty {
                swipePinch.reset()
                tipTap.reset()
                clearGestureContext()
            }
            return
        }

        let zoneEnabled: Bool = {
            switch session.zone {
            case .titlebar: return snap.masters.titlebar
            case .dock: return snap.masters.dock
            case .menubar: return snap.masters.menubar
            case .free: return false
            }
        }()

        guard zoneEnabled else {
            if live.isEmpty {
                swipePinch.reset()
                hopHidePreview()
                clearGestureContext()
            }
            return
        }

        guard let outcome = swipePinch.process(
            frame: frame,
            zone: session.zone,
            sensitivity: snap.trackpadSensitivity
        ) else {
            if live.isEmpty { clearGestureContext() }
            return
        }

        switch session.zone {
        case .titlebar:
            applyTitlebar(outcome, snap: snap)
        case .dock:
            applyDock(outcome, snap: snap)
        case .menubar:
            applyMenubar(outcome, snap: snap)
        case .free:
            break
        }

        if live.isEmpty {
            clearGestureContext()
        }
    }

    private func clearGestureContext() {
        session.window = nil
        session.dockApp = nil
        session.loggedPreviewLayout = nil
        session.pinchCandidate = nil
        session.peakFingers = 0
        session.dragBegan = false
        sessionReady = false
        awaitingBegin = false
        hadTouches = false
        fourFingerTap.reset()
    }

    // MARK: - Free space

    private func handleFreeSpace(frame: TouchFrame, fingers: Int, snap: RuntimeSnapshot) {
        session.peakFingers = max(session.peakFingers, fingers)

        if session.peakFingers <= 2 {
            handleFreeSpaceTipTap(frame: frame, snap: snap)
            return
        }

        if session.peakFingers >= 4 {
            if threeFingerDrag.isDragging {
                ClickEmitter.mouseUp(.left)
                Log.info(.gesture, "3F drag released — 4-finger chord took over")
            }
            threeFingerDrag.reset()
            session.dragBegan = false

            if handleFreeSpaceSwipes(frame: frame, snap: snap) { return }
            if fourFingerTap.process(frame: frame, sensitivity: snap.trackpadSensitivity) == .tap {
                runSlot(GestureSlots.ID.free4Tap, snap: snap)
            }
            return
        }

        handleFreeSpaceThreeFinger(frame: frame, snap: snap)
        guard !session.dragBegan else { return }
        handleFreeSpaceSwipes(frame: frame, snap: snap)
    }

    private func handleFreeSpaceTipTap(frame: TouchFrame, snap: RuntimeSnapshot) {
        guard case .tipTap(let side) = tipTap.process(
            frame: frame,
            sensitivity: snap.trackpadSensitivity
        ) else { return }
        runSlot(GestureSlots.tipTapSlot(side: side), snap: snap)
    }

    @discardableResult
    private func handleFreeSpaceSwipes(frame: TouchFrame, snap: RuntimeSnapshot) -> Bool {
        guard let outcome = swipePinch.process(
            frame: frame,
            zone: .free,
            sensitivity: snap.trackpadSensitivity
        ) else { return false }

        guard outcome.isCommit, case .swipe(let fingers, let direction) = outcome.gesture else {
            return false
        }
        guard let slotId = GestureSlots.freeSwipeSlot(
            fingers: max(fingers, session.peakFingers),
            direction: direction
        ) else { return false }

        return runSlot(slotId, snap: snap)
    }

    private func handleFreeSpaceThreeFinger(frame: TouchFrame, snap: RuntimeSnapshot) {
        let dragOn = snap.slotOn(GestureSlots.ID.free3Drag)

        switch threeFingerDrag.process(frame: frame, sensitivity: snap.trackpadSensitivity) {
        case .none:
            break
        case .dragBegan(let downAt, let cursor):
            guard dragOn else { break }
            session.dragBegan = true
            ClickEmitter.mouseDown(.left, at: downAt)
            if hypot(cursor.x - downAt.x, cursor.y - downAt.y) >= 0.5 {
                ClickEmitter.mouseDragged(.left, at: cursor)
            }
            if snap.haptics {
                MainHop.async { Haptics.fire(enabled: true) }
            }
        case .dragMoved(let to):
            guard dragOn else { break }
            ClickEmitter.mouseDragged(.left, at: to)
        case .dragEnded(let at):
            guard dragOn else { break }
            ClickEmitter.mouseUp(.left, at: at)
        case .tap:
            runSlot(GestureSlots.ID.free3Tap, snap: snap)
            TutorialPrefs.post(.trackpadMiddleClick)
        }
    }

    @discardableResult
    private func runSlot(_ slotId: String, snap: RuntimeSnapshot, clickCount: Int = 1) -> Bool {
        guard snap.slotOn(slotId), let actionId = snap.actionId(for: slotId) else {
            return false
        }
        var ctx = ActionContext(
            window: session.window,
            dockApp: session.dockApp,
            gap: CGFloat(snap.gap),
            haptics: snap.haptics
        )
        ctx.clickCount = clickCount
        Log.info(.gesture, "slot=\(slotId) → \(actionId)")
        GestureActivity.announce(slotId: slotId)
        let hud = snap.hudEnabled
        MainHop.async {
            _ = GestureEngine.shared.perform(actionId, context: ctx, hudEnabled: hud)
        }
        return true
    }

    @MainActor
    @discardableResult
    private func perform(_ actionId: String, context: ActionContext, hudEnabled: Bool) -> Bool {
        let result = ActionRunner.execute(actionId, context: context)
        if hudEnabled {
            if result.ok, ActionCatalog.announcesInHUD(actionId), let title = result.hudTitle {
                HUDController.shared.show(title: title)
            } else if !result.ok, let err = result.errorTitle {
                HUDController.shared.show(title: err)
            }
        }
        return result.ok
    }

    private func continuousThirdsAction(
        slotId: String,
        actionId: String,
        direction: SwipeDirection,
        magnitude: CGFloat,
        cycle: Bool
    ) -> String? {
        guard cycle else { return nil }
        switch (slotId, actionId, direction) {
        case (GestureSlots.ID.tbLeft, ActionCatalog.ID.snapLeftHalf, .left):
            return ActionCatalog.actionId(for: LayoutGeometry.continuousLeftLayout(magnitude: magnitude))
        case (GestureSlots.ID.tbRight, ActionCatalog.ID.snapRightHalf, .right):
            return ActionCatalog.actionId(for: LayoutGeometry.continuousRightLayout(magnitude: magnitude))
        default:
            return nil
        }
    }

    // MARK: - Titlebar

    private func applyTitlebar(_ outcome: SwipePinchRecognizer.Outcome, snap: RuntimeSnapshot) {
        let gap = CGFloat(snap.gap)
        let window = session.window

        switch outcome.gesture {
        case .pinch(let inward):
            if outcome.isPreview {
                session.pinchCandidate = inward
                hopHidePreview()
                return
            }
            let inward = session.pinchCandidate ?? inward
            session.pinchCandidate = nil
            runSlot(GestureSlots.titlebarPinchSlot(inward: inward), snap: snap)

        case .swipe(let fingers, let direction):
            let cycle = snap.cycleThirds
            guard let slotId = GestureSlots.titlebarSwipeSlot(
                fingers: fingers,
                direction: direction,
                magnitude: outcome.magnitude,
                cycleThirds: cycle
            ) else {
                if outcome.isCommit { hopHidePreview() }
                return
            }

            guard snap.slotOn(slotId), let resolvedAction = snap.actionId(for: slotId) else {
                if outcome.isCommit { hopHidePreview() }
                return
            }

            let actionId = continuousThirdsAction(
                slotId: slotId,
                actionId: resolvedAction,
                direction: direction,
                magnitude: outcome.magnitude,
                cycle: cycle
            ) ?? resolvedAction

            if outcome.isPreview {
                if let layout = ActionCatalog.snapLayout(for: actionId), snap.showPreview {
                    if session.loggedPreviewLayout != layout {
                        session.loggedPreviewLayout = layout
                        Log.debug(.gesture, "titlebar preview \(layout.rawValue) slot=\(slotId)")
                        MainHop.async {
                            WindowManager.shared.showPreview(layout: layout, gap: gap, for: window)
                        }
                    }
                } else if session.loggedPreviewLayout != nil {
                    session.loggedPreviewLayout = nil
                    hopHidePreview()
                }
            } else if outcome.isCommit {
                hopHidePreview()
                GestureActivity.announce(slotId: slotId)
                let ctx = ActionContext(
                    window: window,
                    dockApp: session.dockApp,
                    gap: gap,
                    haptics: snap.haptics
                )
                let hud = snap.hudEnabled
                MainHop.async {
                    _ = GestureEngine.shared.perform(actionId, context: ctx, hudEnabled: hud)
                }
                if ActionCatalog.snapLayout(for: actionId) != nil
                    || actionId == ActionCatalog.ID.minimize
                    || actionId == ActionCatalog.ID.restore
                {
                    TutorialPrefs.post(.titlebarSnap)
                }
            }

        default:
            break
        }
    }

    private func hopHidePreview() {
        MainHop.async { WindowManager.shared.hidePreview() }
    }

    // MARK: - Dock

    private func applyDock(_ outcome: SwipePinchRecognizer.Outcome, snap: RuntimeSnapshot) {
        if outcome.isPreview {
            if case .pinch(let inward) = outcome.gesture {
                session.pinchCandidate = inward
            }
            return
        }
        guard outcome.isCommit else { return }

        switch outcome.gesture {
        case .swipe(_, let direction):
            guard let slotId = GestureSlots.dockSwipeSlot(direction: direction) else { return }
            if session.dockApp == nil {
                Log.warn(.gesture, "dock gesture — no app under cursor")
                return
            }
            _ = runSlot(slotId, snap: snap)
            if slotId == GestureSlots.ID.dockUp {
                TutorialPrefs.post(.dockActivate)
            }

        case .pinch(let inward):
            let inward = session.pinchCandidate ?? inward
            session.pinchCandidate = nil
            let slotId = GestureSlots.dockPinchSlot(inward: inward)
            if session.dockApp == nil {
                Log.warn(.gesture, "dock pinch — no app under cursor")
                return
            }
            _ = runSlot(slotId, snap: snap)

        default:
            break
        }
    }

    // MARK: - Menubar

    private func applyMenubar(_ outcome: SwipePinchRecognizer.Outcome, snap: RuntimeSnapshot) {
        if outcome.isPreview { return }
        guard outcome.isCommit else { return }

        switch outcome.gesture {
        case .swipe(_, let direction):
            guard let slotId = GestureSlots.menubarSwipeSlot(direction: direction) else { return }
            _ = runSlot(slotId, snap: snap)
        default:
            break
        }
    }
}
