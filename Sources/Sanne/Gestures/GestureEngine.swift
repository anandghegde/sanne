import AppKit
import ApplicationServices
import Foundation

/// Trackpad zone gestures (titlebar / Dock / menubar). Magic Mouse taps: `MagicMouseTapController`.
/// Actions resolve through `BindingResolver` + `ActionRunner` so remaps apply.
final class GestureEngine: @unchecked Sendable {
    static let shared = GestureEngine()

    private let swipePinch = SwipePinchRecognizer()
    private let taps = TapRecognizer()
    private let threeFingerDrag = ThreeFingerDragRecognizer()
    private let tipTap = TipTapRecognizer()
    private var listenerID: UUID?

    private var zoneAtGestureStart: CursorZone = .free
    /// Window under cursor when fingers first touch (titlebar path).
    private var windowAtGestureStart: AXUIElement?
    /// Dock app under cursor at gesture begin.
    private var dockAppAtGestureStart: NSRunningApplication?
    private var hadTouches = false
    private var pinchCandidate: Bool?
    private var loggedPreviewLayout: WindowLayout?
    /// Peak simultaneous contacts in the current free-space session (routes 3F vs 4F slots).
    private var freePeakFingers = 0
    /// A 3-finger drag committed during this free-space session — drag beats swipe.
    private var freeDragBegan = false

    /// Frontmost app when the current touch gesture began.
    ///
    /// Snapshotted rather than read live so a per-app binding is decided once — a gesture that
    /// happens to change focus mid-flight still runs the action it started out meaning — and so
    /// `NSWorkspace` isn't consulted on every touch frame.
    private var frontmostBundleIdAtGestureStart: String?

    private static var frontmostBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private var configProvider: () -> SanneConfig = { .default }
    private var isPaused: () -> Bool = { false }
    private var isMagicMousePaused: () -> Bool = { false }

    func start(
        config: @escaping () -> SanneConfig,
        paused: @escaping () -> Bool,
        magicMousePaused: (() -> Bool)? = nil
    ) {
        configProvider = config
        isPaused = paused
        isMagicMousePaused = magicMousePaused ?? paused

        MagicMouseTapController.shared.start(
            config: config,
            paused: { GestureEngine.shared.isMagicMousePaused() },
            onEvent: { event in
                Task { @MainActor in
                    GestureEngine.shared.handleMagicMouse(event)
                }
            }
        )

        guard listenerID == nil else { return }
        listenerID = TouchDeviceManager.shared.addListener { [weak self] frame in
            DispatchQueue.main.async {
                self?.handleOnMain(frame)
            }
        }
        Log.info(.gesture, "GestureEngine started (titlebar + Dock + menubar + Magic Mouse taps)")
    }

    func stop() {
        // The fade would clear it within a second anyway, but a HUD naming an action while Sanne is
        // being switched off reads like the gesture is still live.
        Task { @MainActor in HUDController.shared.hide() }
        MagicMouseTapController.shared.stop()
        if let listenerID {
            TouchDeviceManager.shared.removeListener(listenerID)
        }
        listenerID = nil
        if threeFingerDrag.isDragging {
            ClickEmitter.mouseUp(.left)
        }
        threeFingerDrag.reset()
        swipePinch.reset()
        tipTap.reset()
        freePeakFingers = 0
        freeDragBegan = false
        windowAtGestureStart = nil
        dockAppAtGestureStart = nil
    }

    // MARK: - Magic Mouse

    @MainActor
    private func handleMagicMouse(_ event: MagicMouseEvent) {
        if isMagicMousePaused() { return }
        let config = configProvider()
        switch event {
        case .recognized(let slotId, let clickCount):
            // Read live rather than from the touch path's snapshot: Magic Mouse events arrive
            // already recognized, so this is the first moment the engine sees the gesture at all.
            guard let resolved = BindingResolver.resolve(
                slotId: slotId,
                config: config,
                frontmostBundleId: Self.frontmostBundleId
            ), resolved.enabled else {
                Log.debug(.gesture, "MagicMouse slot=\(slotId) disabled")
                return
            }
            Log.info(.gesture, "MagicMouse slot=\(slotId) → \(resolved.actionId)×\(clickCount)")
            var ctx = makeContext(config: config)
            // Multi-click only when still performing left-click.
            if resolved.actionId == ActionCatalog.ID.clickLeft {
                ctx.clickCount = config.magicMouseTaps.multiClick ? clickCount : 1
            }
            perform(resolved.actionId, context: ctx, config: config)
            if slotId == GestureSlots.ID.mmLeft || resolved.actionId == ActionCatalog.ID.clickLeft {
                TutorialPrefs.post(.magicMouseClick)
            }
            if resolved.actionId == ActionCatalog.ID.clickMiddle {
                TutorialPrefs.post(.trackpadMiddleClick)
            }
        }
    }

    // MARK: - Trackpad frames

    @MainActor
    private func handleOnMain(_ frame: TouchFrame) {
        if isPaused() {
            if threeFingerDrag.isDragging {
                ClickEmitter.mouseUp(.left)
                threeFingerDrag.reset()
            }
            swipePinch.reset()
            tipTap.reset()
            freePeakFingers = 0
            freeDragBegan = false
            return
        }
        let config = configProvider()
        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }

        if !hadTouches, !live.isEmpty {
            let point = NSEvent.mouseLocation
            zoneAtGestureStart = ZoneClassifier.zone(at: point)
            pinchCandidate = nil
            loggedPreviewLayout = nil
            windowAtGestureStart = nil
            dockAppAtGestureStart = nil
            freePeakFingers = 0
            freeDragBegan = false
            frontmostBundleIdAtGestureStart = Self.frontmostBundleId

            switch zoneAtGestureStart {
            case .titlebar:
                windowAtGestureStart = WindowManager.shared.windowAt(appKitPoint: point)
                Log.info(
                    .gesture,
                    "gesture begin zone=titlebar fingers=\(live.count) " +
                    "window=\(windowAtGestureStart != nil ? "yes" : "nil") " +
                    "cursor=(\(Int(point.x)),\(Int(point.y)))"
                )
            case .dock:
                dockAppAtGestureStart = ZoneActions.dockApp(at: point)
                Log.info(
                    .gesture,
                    "gesture begin zone=dock fingers=\(live.count) " +
                    "app=\(dockAppAtGestureStart?.localizedName ?? "nil") " +
                    "cursor=(\(Int(point.x)),\(Int(point.y)))"
                )
            case .menubar:
                Log.info(
                    .gesture,
                    "gesture begin zone=menubar fingers=\(live.count) " +
                    "cursor=(\(Int(point.x)),\(Int(point.y)))"
                )
            case .free:
                if live.count >= 2 {
                    Log.debug(.gesture, "gesture begin zone=free fingers=\(live.count)")
                }
            }
        }
        hadTouches = !live.isEmpty

        // Trackpad free-space owns its own arbitration (drag / swipe / tap / tip-tap) and never
        // drives window-zone previews, so it handles the frame and returns.
        if zoneAtGestureStart == .free {
            handleFreeSpace(frame: frame, fingers: live.count, config: config)
            if live.isEmpty {
                swipePinch.reset()
                // Clear here as well as inside the recognizer: a session that ended while a
                // 3+ chord was suppressing the tip-tap path never saw its own lift frame.
                tipTap.reset()
                clearGestureContext()
            }
            return
        }

        let zone = zoneAtGestureStart
        let zoneEnabled: Bool = {
            switch zone {
            case .titlebar: return config.titlebarGestures.enabled
            case .dock: return config.dockGestures.enabled
            case .menubar: return config.menubarGestures.enabled
            case .free: return false
            }
        }()

        guard zoneEnabled else {
            if live.isEmpty {
                swipePinch.reset()
                WindowManager.shared.hidePreview()
                clearGestureContext()
            }
            return
        }

        guard let outcome = swipePinch.process(
            frame: frame,
            zone: zone,
            sensitivity: config.trackpad.sensitivity
        ) else {
            if live.isEmpty { clearGestureContext() }
            return
        }

        switch zone {
        case .titlebar:
            applyTitlebar(outcome, config: config)
        case .dock:
            applyDock(outcome, config: config)
        case .menubar:
            applyMenubar(outcome, config: config)
        case .free:
            break
        }

        if live.isEmpty {
            clearGestureContext()
        }
    }

    private func clearGestureContext() {
        windowAtGestureStart = nil
        dockAppAtGestureStart = nil
        loggedPreviewLayout = nil
    }

    // MARK: - Free space

    /// Free-space arbitration, highest priority first:
    ///
    /// 1. **3-finger drag** — once a drag commits it owns the session (a swipe would leave a
    ///    stuck mouse button). With drag enabled its 0.028 travel threshold trips before the
    ///    0.08 swipe threshold, so 3-finger swipes are in practice a "drag off" gesture.
    /// 2. **Swipe** — 3F or 4F, by the peak contact count of the session.
    /// 3. **Tap** — only when nothing travelled far enough to be a swipe.
    ///
    /// The peak count is sticky for the whole session so a 4-finger chord that loses a finger
    /// mid-swipe cannot also fire the 3-finger slot.
    ///
    /// Tip-tap sits outside that ladder entirely: it needs one resting finger plus one tapping
    /// finger, so it only exists in the 1–2 contact range while every gesture above requires a
    /// 3+ chord. The split is structural, not threshold-tuned, which is why a session can never
    /// fire both a tip-tap and a chord gesture.
    @MainActor
    private func handleFreeSpace(frame: TouchFrame, fingers: Int, config: SanneConfig) {
        freePeakFingers = max(freePeakFingers, fingers)

        if freePeakFingers <= 2 {
            handleFreeSpaceTipTap(frame: frame, config: config)
            return
        }

        if freePeakFingers >= 4 {
            // A drag may have started before the fourth finger landed — let go rather than
            // smear a selection while the user swipes.
            if threeFingerDrag.isDragging {
                ClickEmitter.mouseUp(.left)
                Log.info(.gesture, "3F drag released — 4-finger chord took over")
            }
            threeFingerDrag.reset()
            freeDragBegan = false

            if handleFreeSpaceSwipes(frame: frame, config: config) { return }
            if taps.processTrackpadThreeFingerTap(frame: frame) {
                runSlot(GestureSlots.ID.free4Tap, config: config)
            }
            return
        }

        handleFreeSpaceThreeFinger(frame: frame, config: config)
        guard !freeDragBegan else { return }
        handleFreeSpaceSwipes(frame: frame, config: config)
    }

    /// Runs the tip-tap state machine. Only reached while the session has never exceeded two
    /// contacts, so it cannot compete with the chord gestures.
    @MainActor
    private func handleFreeSpaceTipTap(frame: TouchFrame, config: SanneConfig) {
        guard case .tipTap(let side) = tipTap.process(
            frame: frame,
            sensitivity: config.trackpad.sensitivity
        ) else { return }

        runSlot(GestureSlots.tipTapSlot(side: side), config: config)
    }

    /// Commits a free-space 3F/4F swipe. Previews are ignored — free space has no preview.
    @MainActor
    @discardableResult
    private func handleFreeSpaceSwipes(frame: TouchFrame, config: SanneConfig) -> Bool {
        guard let outcome = swipePinch.process(
            frame: frame,
            zone: .free,
            sensitivity: config.trackpad.sensitivity
        ) else { return false }

        guard outcome.isCommit, case .swipe(let fingers, let direction) = outcome.gesture else {
            return false
        }
        guard let slotId = GestureSlots.freeSwipeSlot(
            fingers: max(fingers, freePeakFingers),
            direction: direction
        ) else { return false }

        return runSlot(slotId, config: config)
    }

    // MARK: - Free-space 3-finger (drag + middle-click tap)

    @MainActor
    private func handleFreeSpaceThreeFinger(frame: TouchFrame, config: SanneConfig) {
        let dragOn = BindingResolver.resolve(
            slotId: GestureSlots.ID.free3Drag,
            config: config,
            frontmostBundleId: frontmostBundleIdAtGestureStart
        )?.enabled ?? config.trackpad.threeFingerDrag

        if dragOn {
            switch threeFingerDrag.process(frame: frame, sensitivity: config.trackpad.sensitivity) {
            case .none:
                break
            case .dragBegan(let downAt, let cursor):
                freeDragBegan = true
                ClickEmitter.mouseDown(.left, at: downAt)
                if hypot(cursor.x - downAt.x, cursor.y - downAt.y) >= 0.5 {
                    ClickEmitter.mouseDragged(.left, at: cursor)
                }
                Haptics.fire(enabled: config.window.haptics)
            case .dragMoved(let to):
                ClickEmitter.mouseDragged(.left, at: to)
            case .dragEnded(let at):
                ClickEmitter.mouseUp(.left, at: at)
            case .tap:
                runSlot(GestureSlots.ID.free3Tap, config: config)
                TutorialPrefs.post(.trackpadMiddleClick)
            }
            return
        }

        // Drag off: legacy 3-finger tap only.
        if threeFingerDrag.isDragging {
            ClickEmitter.mouseUp(.left)
            threeFingerDrag.reset()
        }
        if taps.processTrackpadThreeFingerTap(frame: frame) {
            runSlot(GestureSlots.ID.free3Tap, config: config)
            TutorialPrefs.post(.trackpadMiddleClick)
        }
    }

    @MainActor
    private func makeContext(config: SanneConfig) -> ActionContext {
        ActionContext(
            window: windowAtGestureStart,
            dockApp: dockAppAtGestureStart,
            gap: CGFloat(config.window.gap),
            haptics: config.window.haptics
        )
    }

    @MainActor
    @discardableResult
    private func runSlot(_ slotId: String, config: SanneConfig, clickCount: Int = 1) -> Bool {
        guard let resolved = BindingResolver.resolve(
            slotId: slotId,
            config: config,
            frontmostBundleId: frontmostBundleIdAtGestureStart
        ), resolved.enabled else {
            return false
        }
        var ctx = makeContext(config: config)
        ctx.clickCount = clickCount
        Log.info(.gesture, "slot=\(slotId) → \(resolved.actionId)")
        return perform(resolved.actionId, context: ctx, config: config)
    }

    /// Runs an action and announces it in the HUD.
    ///
    /// The engine's only route to `ActionRunner.run`, so "every committed action announces exactly
    /// once" is a property of the code shape rather than of remembering to add a call: `runSlot`
    /// covers the free-space, Dock and menubar paths, `applyTitlebar` calls it directly for the one
    /// commit that needs the resolved action before running it, and `handleMagicMouse` for the one
    /// that needs a click count. Nothing else in this file may call the runner.
    ///
    /// Announcing only on success keeps the HUD honest — a snap with no window under the cursor did
    /// not happen and must not claim to.
    @MainActor
    @discardableResult
    private func perform(_ actionId: String, context: ActionContext, config: SanneConfig) -> Bool {
        let ok = ActionRunner.run(actionId, context: context)
        if ok, config.hud.enabled, ActionCatalog.announcesInHUD(actionId) {
            HUDController.shared.show(title: ActionCatalog.title(for: actionId))
        }
        return ok
    }

    // MARK: - Titlebar

    @MainActor
    private func applyTitlebar(_ outcome: SwipePinchRecognizer.Outcome, config: SanneConfig) {
        let gap = CGFloat(config.window.gap)
        let window = windowAtGestureStart

        switch outcome.gesture {
        case .pinch(let inward):
            if outcome.isPreview {
                pinchCandidate = inward
                WindowManager.shared.hidePreview()
                return
            }
            let inward = pinchCandidate ?? inward
            pinchCandidate = nil
            let slotId = GestureSlots.titlebarPinchSlot(inward: inward)
            _ = runSlot(slotId, config: config)

        case .swipe(let fingers, let direction):
            guard let slotId = GestureSlots.titlebarSwipeSlot(
                fingers: fingers,
                direction: direction,
                magnitude: outcome.magnitude
            ) else {
                if outcome.isCommit { WindowManager.shared.hidePreview() }
                return
            }

            guard let resolved = BindingResolver.resolve(
                slotId: slotId,
                config: config,
                frontmostBundleId: frontmostBundleIdAtGestureStart
            ), resolved.enabled else {
                if outcome.isCommit { WindowManager.shared.hidePreview() }
                return
            }

            if outcome.isPreview {
                if let layout = ActionCatalog.snapLayout(for: resolved.actionId), config.window.showPreview {
                    if loggedPreviewLayout != layout {
                        loggedPreviewLayout = layout
                        Log.debug(.gesture, "titlebar preview \(layout.rawValue) slot=\(slotId)")
                    }
                    WindowManager.shared.showPreview(layout: layout, gap: gap, for: window)
                } else {
                    WindowManager.shared.hidePreview()
                }
            } else if outcome.isCommit {
                WindowManager.shared.hidePreview()
                let ctx = makeContext(config: config)
                perform(resolved.actionId, context: ctx, config: config)
                if ActionCatalog.snapLayout(for: resolved.actionId) != nil
                    || resolved.actionId == ActionCatalog.ID.minimize
                {
                    TutorialPrefs.post(.titlebarSnap)
                }
            }

        default:
            break
        }
    }

    // MARK: - Dock

    @MainActor
    private func applyDock(_ outcome: SwipePinchRecognizer.Outcome, config: SanneConfig) {
        if outcome.isPreview {
            if case .pinch(let inward) = outcome.gesture {
                pinchCandidate = inward
            }
            return
        }
        guard outcome.isCommit else { return }

        // Ensure dock app is available for dock actions.
        if dockAppAtGestureStart == nil {
            dockAppAtGestureStart = ZoneActions.dockApp()
        }

        switch outcome.gesture {
        case .swipe(_, let direction):
            guard let slotId = GestureSlots.dockSwipeSlot(direction: direction) else { return }
            if dockAppAtGestureStart == nil {
                Log.warn(.gesture, "dock gesture — no app under cursor")
                return
            }
            _ = runSlot(slotId, config: config)

        case .pinch(let inward):
            let inward = pinchCandidate ?? inward
            pinchCandidate = nil
            let slotId = GestureSlots.dockPinchSlot(inward: inward)
            if dockAppAtGestureStart == nil {
                Log.warn(.gesture, "dock pinch — no app under cursor")
                return
            }
            _ = runSlot(slotId, config: config)

        default:
            break
        }
    }

    // MARK: - Menubar

    @MainActor
    private func applyMenubar(_ outcome: SwipePinchRecognizer.Outcome, config: SanneConfig) {
        if outcome.isPreview { return }
        guard outcome.isCommit else { return }

        switch outcome.gesture {
        case .swipe(_, let direction):
            guard let slotId = GestureSlots.menubarSwipeSlot(direction: direction) else { return }
            _ = runSlot(slotId, config: config)
        default:
            break
        }
    }
}
