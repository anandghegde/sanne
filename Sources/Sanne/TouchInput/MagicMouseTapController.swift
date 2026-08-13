import Foundation
import CoreGraphics
import AppKit

/// High-level Magic Mouse recognizer output (taps + multi-finger gestures).
/// `slotId` matches `GestureSlots.ID` for remapping.
enum MagicMouseEvent: Equatable {
    case recognized(slotId: String, clickCount: Int)
}

/// Magic Mouse surface gestures via MultitouchSupport (TapToClick + popular BTT/Multitouch set).
final class MagicMouseTapController: @unchecked Sendable {
    static let shared = MagicMouseTapController()

    private var retainedLists: [CFArray] = []
    private var devices: [PrivateMT.DeviceRef] = []
    private var started = false
    private let lock = NSLock()

    private var configProvider: () -> SanneConfig = { .default }
    private var isPaused: () -> Bool = { false }
    private var onEvent: ((MagicMouseEvent) -> Void)?

    private var activeTouchID: Int32 = -1
    private var touchStartX: Float = 0
    private var touchStartY: Float = 0
    private var touchStartTime: Date?
    private var touchStartCursor: CGPoint = .zero
    private var maxSurfaceMove: Float = 0
    private var maxVelocity: Float = 0
    /// Peak contact size (MT `size` ≈ pressure/area). Feather grazes stay near 0;
    /// deliberate finger taps read ≈0.4+. 0 means the sensor never reported size.
    private var maxTouchSize: Float = 0
    /// Signed net displacement from touch start (updated every frame).
    private var netDx: Float = 0
    private var netDy: Float = 0
    /// 1-finger horizontal page swipe in progress (do not treat as tap).
    private var pageSwipeActive = false
    private var multiFinger = false
    private var multiFingerCount = 0
    /// Contacts credited to a *swipe*, frozen once the chord is clearly travelling.
    ///
    /// `multiFingerCount` is a running max over the whole session, which is right for taps
    /// (fingers land a few frames apart) but wrong for swipes: on a Magic Mouse the spare
    /// fingers rest on the shell, so a pinky grazing halfway through a 2-finger swipe would
    /// otherwise promote it into the 3-finger slots.
    private var multiSwipeFingers = 0
    private var multiStartCentroid: CGPoint = .zero
    private var multiLastCentroid: CGPoint = .zero
    private var multiMaxTravel: Float = 0
    /// After scroll/drag cancel, ignore contacts until full lift.
    private var suppressUntilLift = false
    /// True when current suppress-until-lift was caused by a vertical surface scroll.
    private var suppressedForScroll = false
    /// No single-finger clicks until this time. Extended by surface-scroll + OS scroll-wheel.
    /// This is what Multitouch/BTT get right: residual finger repositions after scroll
    /// look identical to taps (logs: false LEFT 0.4–0.75s after scroll cancel).
    private var noTapUntil: Date?
    /// Last time any Magic Mouse contact was seen (gates scroll-wheel → noTap correlation).
    private var lastMouseTouchTime: Date?
    private var scrollWheelMonitor: Any?
    /// Hardware mouse-down while a contact is active (or just lifted).
    private var mouseClickGlobalMonitor: Any?
    private var mouseClickLocalMonitor: Any?
    /// Physical press during this contact — synthetic tap would double-click with hardware.
    private var physicalClickDuringContact = false
    /// Last hardware click time (covers race: mouseDown just after we start finishTap path).
    private var lastPhysicalClickTime: Date?
    /// Suppress synthetic if physical click was this recent (BTT-style; design: ~30ms, use 80ms slack).
    private static let physicalClickSuppressWindow: TimeInterval = 0.08
    /// After we post a synthetic click/drag, local monitors can see our own CGEvent echo —
    /// ignore mouseDown until this time so multi-click / next tap still work.
    private var ignorePhysicalEchoUntil: Date?
    private static let syntheticEchoIgnore: TimeInterval = 0.06
    private var callbackCount = 0

    // MARK: Scroll-session lock (BTT/Multitouch-style)

    /// How long after a *surface* scroll cancel we refuse taps (covers residual repositions).
    private static let surfaceScrollLock: TimeInterval = 0.90
    /// How long after a meaningful OS scroll-wheel event (live finger scroll).
    /// Logs show residual repositions landing 0.4–0.9s after the last wheel event,
    /// so 0.55 leaked ghost clicks — keep in line with surfaceScrollLock territory.
    private static let wheelScrollLock: TimeInterval = 0.75
    /// Momentum / inertia tail after last wheel event. Same leak as wheelScrollLock:
    /// 0.40 let contacts beginning 0.4–0.9s after momentum end click (see sanne.log).
    private static let momentumScrollLock: TimeInterval = 0.75
    /// Residuals arrive in chains — a lift rejected by the scroll lock predicts another
    /// residual right behind it, so each rejected lift re-arms the lock by this much.
    private static let residualRepositionLock: TimeInterval = 0.40
    /// Ignore scroll-wheel unless MM was touched recently (don't lock from trackpad).
    private static let wheelTouchCorrelation: TimeInterval = 1.5
    /// Ignore tiny wheel noise (pure taps must not arm the lock).
    private static let wheelDeltaMin: CGFloat = 1.5
    /// Contacts whose size never exceeds this are grazes (finger brushing while
    /// gripping / repositioning the mouse) — not taps. Size 0 = unavailable → skip check.
    private static let minTouchSize: Float = 0.08

    // MARK: Tap-drag (double-tap-hold)

    private enum DragPhase: String {
        case none
        case pendingHold
        case active
    }

    private var dragPhase: DragPhase = .none
    private var lastLeftTapTime: Date?
    private var lastDragPostedCursor: CGPoint = .zero
    private static let doubleTapWindow: TimeInterval = 0.35
    private static let dragHoldMin: TimeInterval = 0.15

    /// Effective double-tap-hold binding. Enable and action both come from
    /// `BindingResolver` so a remap or a row-toggle beats the legacy `tapDrag` flag.
    private static func resolvedDrag(_ config: SanneConfig) -> ResolvedGesture? {
        BindingResolver.resolve(
            slotId: GestureSlots.ID.mmDrag,
            config: config,
            frontmostBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }

    private static func dragSlotEnabled(_ config: SanneConfig) -> Bool {
        resolvedDrag(config)?.enabled ?? false
    }

    // MARK: Multi-click (double / triple)

    private var lastClickTime: Date?
    private var lastClickButton: ClickButton?
    private var lastClickCount: Int = 0
    private var lastClickCursor: CGPoint = .zero
    /// System double-click interval (~0.5s default); slightly generous for taps.
    private static let multiClickWindow: TimeInterval = 0.45
    private static let multiClickMaxCursorDist: CGFloat = 6

    // MARK: 2-finger double-tap → Mission Control

    private var lastTwoFingerTapTime: Date?
    private var pendingTwoFingerMiddleWorkItem: DispatchWorkItem?
    private static let twoFingerDoubleWindow: TimeInterval = 0.32

    // MARK: 2-finger top-edge → move window

    private enum WindowMovePhase: String {
        case none
        case active
    }

    private var windowMovePhase: WindowMovePhase = .none
    private var multiStartY: Float = 0
    /// Normalized Y ≥ this at multi-begin counts as top edge (norm Y increases toward top).
    private static let topEdgeMinY: Float = 0.58
    /// Cursor travel (pt) before committing window move.
    private static let windowMoveCursorMin: CGFloat = 6
    /// Surface travel above this → treat as swipe, not window move.
    private static let windowMoveMaxSurface: Float = 0.055

    /// Tap vs scroll / page-swipe thresholds.
    /// Peak frame velocity is noisy — use net surface travel. Vertical slide = scroll;
    /// horizontal slide = swipe-between-pages (macOS gesture breaks once we claim MT).
    private struct Thresholds {
        /// Shortest contact treated as a tap — anything quicker is a graze
        /// (finger brushing the surface while gripping / repositioning the mouse).
        let minDuration: TimeInterval
        /// Longest stationary contact still treated as a tap (not a rest).
        let maxDuration: TimeInterval
        /// Vertical finger slide on surface → scroll; kill mid-gesture / reject on lift.
        let surfaceScroll: Float
        /// Horizontal travel for 1-finger back/forward (must clear this + axis dominance).
        let pageSwipeMin: Float
        /// Cursor jump while finger down (pointer moved a lot → not a stationary tap).
        let cursorMove: CGFloat
        /// Multi-finger swipe travel (normalized). Also the line between a 3-finger swipe and
        /// a 3-finger middle-click: the same chord, told apart only by how far it moved.
        let swipeMin: Float

        init(sensitivity: Int) {
            // s: −2 strict (fewer accidental clicks when scrolling) … +2 lenient (more taps count).
            let s = max(-2, min(2, sensitivity))
            // Higher sensitivity → longer allowed hold + more surface/cursor slop.
            minDuration = 0.035 - Double(s) * 0.005        // 0.045…0.025s
            maxDuration = 0.42 + Double(s) * 0.06          // 0.30…0.54s
            surfaceScroll = Float(0.070 - Double(s) * 0.010) // 0.09…0.05
            // Slightly lower than surfaceScroll so a decisive horizontal flick classifies as page swipe.
            pageSwipeMin = Float(0.085 - Double(s) * 0.008) // ~0.10…0.07
            cursorMove = CGFloat(18.0 + Double(s) * 4.0)    // 10…26 pt
            swipeMin = Float(0.10 - Double(s) * 0.01)
        }
    }

    private static let callback: PrivateMT.ContactCallback = { device, touches, numTouches, timestamp, frame in
        MagicMouseTapController.shared.handle(
            device: device,
            touches: touches,
            numTouches: Int(numTouches),
            timestamp: timestamp,
            frame: frame
        )
        return 0
    }

    func start(
        config: @escaping () -> SanneConfig,
        paused: @escaping () -> Bool,
        onEvent: @escaping (MagicMouseEvent) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.configProvider = config
        self.isPaused = paused
        self.onEvent = onEvent

        if started {
            Log.info(.tap, "MagicMouseTap already started devices=\(devices.count)")
            return
        }

        guard PrivateMT.load() else {
            Log.error(.tap, "MultitouchSupport load failed")
            return
        }
        guard let list = PrivateMT.createDeviceList() else {
            Log.error(.tap, "No multitouch devices")
            return
        }

        retainedLists.append(list.array)

        var registered = 0
        for (i, device) in list.devices.enumerated() {
            let builtIn = PrivateMT.deviceIsBuiltIn(device)
            let opaque = PrivateMT.deviceIsOpaqueSurface(device)
            let force = PrivateMT.deviceSupportsForce(device)
            let isMouse = PrivateMT.isMagicMouseDevice(device)
            Log.info(
                .tap,
                "device[\(i)] builtIn=\(builtIn) opaque=\(opaque) force=\(force) magicMouse=\(isMouse)"
            )

            guard isMouse else {
                Log.info(.tap, "  skip (not Magic Mouse)")
                continue
            }

            devices.append(device)
            PrivateMT.register(device, Self.callback)
            PrivateMT.start(device)
            registered += 1
            Log.info(.tap, "  MONITORING Magic Mouse #\(registered)")
        }

        if registered == 0 {
            Log.warn(.tap, "No Magic Mouse multitouch device found — tap-to-click idle")
        }

        started = true
        callbackCount = 0
        noTapUntil = nil
        physicalClickDuringContact = false
        lastPhysicalClickTime = nil
        startScrollWheelMonitorUnlocked()
        startMouseClickMonitorUnlocked()
        Log.info(.tap, "MagicMouseTap RUNNING monitored=\(registered). Tap the mouse surface.")
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        for d in devices {
            PrivateMT.unregister(d, Self.callback)
            PrivateMT.stop(d)
        }
        devices.removeAll()
        retainedLists.removeAll()
        started = false
        stopScrollWheelMonitorUnlocked()
        stopMouseClickMonitorUnlocked()
        resetUnlocked(clearSuppress: true)
        noTapUntil = nil
        suppressedForScroll = false
        pageSwipeActive = false
        lastMouseTouchTime = nil
        physicalClickDuringContact = false
        lastPhysicalClickTime = nil
        DispatchQueue.main.async {
            TouchWindowMover.shared.end()
        }
        Log.info(.tap, "MagicMouseTap stopped callbacks=\(callbackCount)")
    }

    // MARK: OS scroll-wheel → scroll lock

    /// Real apps (Multitouch/BTT) correlate OS scroll with touch. Pure taps do not produce
    /// meaningful scroll-wheel deltas; residual post-scroll contacts arrive while lock is armed.
    private func startScrollWheelMonitorUnlocked() {
        guard scrollWheelMonitor == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            guard self.started, self.scrollWheelMonitor == nil else { return }
            self.scrollWheelMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.noteScrollWheel(event)
            }
            Log.debug(.tap, "scroll-wheel monitor armed (scroll-session tap lock)")
        }
    }

    private func stopScrollWheelMonitorUnlocked() {
        if let mon = scrollWheelMonitor {
            let m = mon
            scrollWheelMonitor = nil
            DispatchQueue.main.async { NSEvent.removeMonitor(m) }
        }
    }

    private func noteScrollWheel(_ event: NSEvent) {
        let dy = abs(event.scrollingDeltaY)
        let dx = abs(event.scrollingDeltaX)
        guard dy >= Self.wheelDeltaMin || dx >= Self.wheelDeltaMin else { return }

        lock.lock()
        // Only arm when Magic Mouse was recently touched — trackpad scroll must not kill MM taps.
        let recentTouch: Bool = {
            guard let t = lastMouseTouchTime else { return false }
            return Date().timeIntervalSince(t) < Self.wheelTouchCorrelation
        }()
        if recentTouch {
            let isMomentum = !event.momentumPhase.isEmpty
            armNoTapUnlocked(for: isMomentum ? Self.momentumScrollLock : Self.wheelScrollLock, reason: isMomentum ? "wheel-momentum" : "wheel")
        }
        lock.unlock()
    }

    private func armNoTapUnlocked(for duration: TimeInterval, reason: String) {
        let until = Date().addingTimeInterval(duration)
        if let existing = noTapUntil, existing >= until { return }
        noTapUntil = until
        Log.debug(.tap, "no-tap until +\(String(format: "%.2f", duration))s (\(reason))")
    }

    /// Contact must *begin* after the lock expires (not merely end after it).
    private func isTapBlockedUnlocked(contactStart: Date) -> Bool {
        guard let until = noTapUntil else { return false }
        return contactStart < until
    }

    // MARK: Physical click → suppress synthetic (avoid double-click)

    /// Hardware left/right press while the finger is on the surface (or just lifted) must not
    /// also produce a Sanne tap click. BTT/Multitouch do this; without it, press = double-click.
    /// Global monitors do not receive same-process CGEvent posts (ClickEmitter), so we only
    /// see real HID clicks. Local monitor covers presses while Sanne is frontmost.
    private func startMouseClickMonitorUnlocked() {
        guard mouseClickGlobalMonitor == nil, mouseClickLocalMonitor == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            guard self.started, self.mouseClickGlobalMonitor == nil else { return }
            let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
            self.mouseClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                self?.notePhysicalMouseDown(event)
            }
            self.mouseClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                self?.notePhysicalMouseDown(event)
                return event
            }
            Log.debug(.tap, "physical-click monitor armed (suppress synthetic on hardware press)")
        }
    }

    private func stopMouseClickMonitorUnlocked() {
        let global = mouseClickGlobalMonitor
        let local = mouseClickLocalMonitor
        mouseClickGlobalMonitor = nil
        mouseClickLocalMonitor = nil
        if global != nil || local != nil {
            DispatchQueue.main.async {
                if let global { NSEvent.removeMonitor(global) }
                if let local { NSEvent.removeMonitor(local) }
            }
        }
    }

    private func notePhysicalMouseDown(_ event: NSEvent) {
        // Ignore non-primary buttons; middle is rare on Magic Mouse hardware.
        guard event.type == .leftMouseDown || event.type == .rightMouseDown else { return }

        lock.lock()
        defer { lock.unlock() }
        guard started else { return }

        // Our own ClickEmitter posts can bounce into the local monitor when Sanne is frontmost.
        if let until = ignorePhysicalEchoUntil, Date() < until {
            return
        }

        // Active single-finger session that could finish as a tap / drag-hold.
        let activeSingle = activeTouchID >= 0 && !multiFinger
        // Contact just ended (lift + finishTap racing with this mouseDown — uncommon but cheap).
        let recentTouch: Bool = {
            guard let t = lastMouseTouchTime else { return false }
            return Date().timeIntervalSince(t) < Self.physicalClickSuppressWindow
        }()
        // Drag hold arming also needs cancel so we don't post a second mouseDown.
        let pendingDrag = dragPhase == .pendingHold

        guard activeSingle || recentTouch || pendingDrag else { return }

        physicalClickDuringContact = true
        lastPhysicalClickTime = Date()
        if dragPhase == .pendingHold {
            dragPhase = .none
        }
        let which = event.type == .leftMouseDown ? "left" : "right"
        Log.debug(.tap, "physical \(which) — suppress synthetic (active=\(activeSingle) recent=\(recentTouch))")
    }

    private func armSyntheticEchoIgnoreUnlocked() {
        ignorePhysicalEchoUntil = Date().addingTimeInterval(Self.syntheticEchoIgnore)
    }

    /// True when this contact (or a just-ended one) already produced a hardware click.
    private func shouldSuppressForPhysicalClickUnlocked() -> Bool {
        if physicalClickDuringContact { return true }
        if let t = lastPhysicalClickTime,
           Date().timeIntervalSince(t) < Self.physicalClickSuppressWindow
        {
            return true
        }
        return false
    }

    func restart() {
        let cfg = configProvider
        let paused = isPaused
        let event = onEvent
        stop()
        Thread.sleep(forTimeInterval: 0.12)
        guard let event else {
            Log.warn(.tap, "MagicMouseTap restart skipped — never started")
            return
        }
        start(config: cfg, paused: paused, onEvent: event)
    }

    private func handle(
        device: Int32,
        touches: UnsafeMutableRawPointer?,
        numTouches: Int,
        timestamp: Double,
        frame: Int32
    ) {
        lock.lock()
        callbackCount += 1
        let n = callbackCount
        let paused = isPaused()
        let full = configProvider()
        let cfg = full.magicMouseTaps
        lock.unlock()

        if !cfg.enabled || paused { return }

        if n <= 40 || numTouches == 0 {
            Log.debug(.tap, "cb#\(n) device=\(device) num=\(numTouches) frame=\(frame)")
        }

        // Full lift
        if numTouches <= 0 {
            lock.lock()
            let phase = dragPhase
            let suppressed = suppressUntilLift
            let wasScroll = suppressedForScroll
            let pageSwipe = pageSwipeActive
            let swipeDx = netDx
            if pageSwipe {
                // Finish 1-finger page swipe on lift (even if we never killed the session).
                let thr = Thresholds(sensitivity: cfg.sensitivity)
                let dx = swipeDx
                resetUnlocked(clearSuppress: true)
                pageSwipeActive = false
                suppressedForScroll = false
                lock.unlock()
                if cfg.oneFingerSwipePages, abs(dx) >= thr.pageSwipeMin {
                    // macOS natural “swipe between pages”: content follows finger —
                    // finger right → previous page (back); finger left → next (forward).
                    emitPageSwipe(dx: dx)
                } else {
                    Log.debug(.tap, "page swipe too short dx=\(String(format: "%.3f", dx))")
                }
                return
            }
            if suppressed {
                // Finger came off after a mid-gesture vertical scroll cancel.
                // Arm a long no-tap window so residual repositions (0.4–0.75s later) don't click.
                if wasScroll {
                    armNoTapUnlocked(for: Self.surfaceScrollLock, reason: "surface-scroll-lift")
                }
                lastMouseTouchTime = Date()
                Log.debug(.tap, "lift while suppressed — no click" + (wasScroll ? " (scroll)" : ""))
                resetUnlocked(clearSuppress: true)
                suppressedForScroll = false
                lock.unlock()
                return
            }
            if phase == .active {
                endActiveDragUnlocked(reason: "lift")
                lock.unlock()
                return
            }
            if windowMovePhase == .active {
                endWindowMoveUnlocked(reason: "lift")
                lock.unlock()
                return
            }
            lock.unlock()
            finishTap(cfg: cfg, reason: "num=\(numTouches)")
            return
        }

        lock.lock()
        let suppressed = suppressUntilLift
        lock.unlock()
        if suppressed { return }

        guard let touches else {
            Log.warn(.tap, "cb#\(n) nil touches ptr")
            return
        }

        // Only physically-touching contacts count. The capacitive sensor also reports
        // fingers *hovering above* the surface (proximity states 1/2/6/7) — those must
        // never start or feed a tap session, or clicks fire without any touch at all.
        var contactIndices: [Int] = []
        for i in 0..<numTouches where PrivateMT.isPhysicalContact(PrivateMT.touch(at: touches, index: i).state) {
            contactIndices.append(i)
        }
        if contactIndices.isEmpty {
            // Pure hover frame (finger near but not on the surface) — ignore.
            if n <= 40 { Log.debug(.tap, "cb#\(n) hover-only frame num=\(numTouches) — ignored") }
            return
        }

        // Multi-finger path (2+ physical contacts)
        if contactIndices.count >= 2 {
            handleMultiFinger(
                touches: touches,
                numTouches: numTouches,
                cfg: cfg,
                n: n
            )
            return
        }

        // Single finger (the one physical contact; hovering extras ignored)
        let t = PrivateMT.touch(at: touches, index: contactIndices[0])
        let nx = t.normX
        let ny = t.normY
        let state = t.state
        let identifier = t.identifier
        let speed = hypot(t.velX, t.velY)
        let thr = Thresholds(sensitivity: cfg.sensitivity)

        if n <= 40 {
            Log.debug(
                .tap,
                "  id=\(identifier) state=\(state) " +
                "xy=(\(String(format: "%.3f", nx)),\(String(format: "%.3f", ny))) " +
                "vel=\(String(format: "%.3f", speed))"
            )
        }

        let cursor = CGEvent(source: nil)?.location ?? .zero

        lock.lock()
        defer { lock.unlock() }

        if multiFinger {
            // Transitioning multi → single: ignore until full lift already handled.
            return
        }

        if activeTouchID < 0 {
            activeTouchID = identifier
            touchStartX = nx
            touchStartY = ny
            touchStartTime = Date()
            touchStartCursor = cursor
            maxSurfaceMove = 0
            maxVelocity = speed
            maxTouchSize = t.size
            netDx = 0
            netDy = 0
            pageSwipeActive = false
            physicalClickDuringContact = false
            lastMouseTouchTime = Date()

            // Don't start tap-drag while scroll lock is active (residual after scroll).
            let blocked = isTapBlockedUnlocked(contactStart: touchStartTime!)
            if Self.dragSlotEnabled(full),
               !blocked,
               let last = lastLeftTapTime,
               Date().timeIntervalSince(last) < Self.doubleTapWindow
            {
                dragPhase = .pendingHold
                lastLeftTapTime = nil
                Log.debug(.tap, "drag pendingHold (double-tap window)")
            } else {
                dragPhase = .none
            }

            Log.debug(
                .tap,
                "touch began id=\(identifier) surface=(\(String(format: "%.3f", nx)),\(String(format: "%.3f", ny))) " +
                "sens=\(cfg.sensitivity) drag=\(dragPhase.rawValue)" +
                (blocked ? " scrollLock=1" : "")
            )
            return
        }

        if activeTouchID != identifier {
            Log.debug(.tap, "touch id \(activeTouchID)→\(identifier); keep session")
            activeTouchID = identifier
        }

        netDx = nx - touchStartX
        netDy = ny - touchStartY
        let surfaceMove = max(abs(netDx), abs(netDy))
        if surfaceMove > maxSurfaceMove { maxSurfaceMove = surfaceMove }
        if speed > maxVelocity { maxVelocity = speed }
        if t.size > maxTouchSize { maxTouchSize = t.size }

        if dragPhase == .active {
            let dist = hypot(cursor.x - lastDragPostedCursor.x, cursor.y - lastDragPostedCursor.y)
            if dist >= 1.0 {
                lastDragPostedCursor = cursor
                let point = cursor
                DispatchQueue.main.async {
                    ClickEmitter.mouseDragged(.left, at: point)
                }
            }
            return
        }

        // Already committed to horizontal page swipe — keep tracking until lift.
        if pageSwipeActive {
            if dragPhase == .pendingHold { dragPhase = .none }
            return
        }

        // Meaningful finger travel: classify vertical scroll vs horizontal page swipe.
        // Do NOT use peak velocity — first frames often spike 0.8–1.7 on real taps.
        if surfaceMove > thr.surfaceScroll {
            let adx = abs(netDx)
            let ady = abs(netDy)
            // Horizontal-dominant → swipe between pages (macOS gesture is broken under MT claim).
            // Ratio 1.05 allows slightly diagonal swipes users actually make.
            if cfg.oneFingerSwipePages, adx > ady * 1.05 {
                pageSwipeActive = true
                if dragPhase == .pendingHold { dragPhase = .none }
                Log.debug(
                    .tap,
                    "page swipe track dx=\(String(format: "%.3f", netDx)) dy=\(String(format: "%.3f", netDy))"
                )
                return
            }
            // Vertical-dominant (or page swipe off) → scroll; no click on this contact.
            Log.debug(.tap, "cancel: surface scroll \(String(format: "%.3f", surfaceMove)) > \(String(format: "%.3f", thr.surfaceScroll))")
            // Arm early (not only on lift) so a quick residual can't sneak in before lift handler runs.
            armNoTapUnlocked(for: Self.surfaceScrollLock, reason: "surface-scroll")
            killSessionUnlocked(reason: "surface")
            return
        }
        // Large cursor jump while finger is planted usually means intentional pointer move / scroll.
        let cursorDist = hypot(cursor.x - touchStartCursor.x, cursor.y - touchStartCursor.y)
        if cursorDist > thr.cursorMove {
            Log.debug(.tap, "cancel: cursor \(String(format: "%.1f", cursorDist)) > \(String(format: "%.0f", thr.cursorMove))")
            killSessionUnlocked(reason: "cursor")
            return
        }

        if dragPhase == .pendingHold, let start = touchStartTime {
            let held = Date().timeIntervalSince(start)
            if held >= Self.dragHoldMin {
                lastClickTime = nil
                lastClickCount = 0
                let resolved = Self.resolvedDrag(full)
                if resolved?.enabled == true, resolved?.actionId == ActionCatalog.ID.drag {
                    dragPhase = .active
                    lastDragPostedCursor = cursor
                    let point = cursor
                    Log.info(.tap, "→ BEGIN DRAG held=\(String(format: "%.3f", held))")
                    armSyntheticEchoIgnoreUnlocked()
                    DispatchQueue.main.async {
                        ClickEmitter.mouseDown(.left, at: point)
                    }
                } else if resolved?.enabled == true {
                    // Remapped off Drag (hold): fire once at hold-commit, don't start a session.
                    dragPhase = .none
                    suppressUntilLift = true
                    Log.info(
                        .tap,
                        "→ DOUBLE-TAP HOLD → \(resolved?.actionId ?? "") " +
                        "held=\(String(format: "%.3f", held))"
                    )
                    emit(.recognized(slotId: GestureSlots.ID.mmDrag, clickCount: 1))
                } else {
                    dragPhase = .none
                }
            }
        }
    }

    private func handleMultiFinger(
        touches: UnsafeMutableRawPointer,
        numTouches: Int,
        cfg: MagicMouseTapConfig,
        n: Int
    ) {
        let thr = Thresholds(sensitivity: cfg.sensitivity)
        var points: [CGPoint] = []
        var peakVel: Float = 0
        for i in 0..<numTouches {
            let t = PrivateMT.touch(at: touches, index: i)
            // Hovering fingers (proximity states) are not on the surface — skip.
            guard PrivateMT.isPhysicalContact(t.state) else { continue }
            points.append(CGPoint(x: CGFloat(t.normX), y: CGFloat(t.normY)))
            peakVel = max(peakVel, hypot(t.velX, t.velY))
        }
        guard points.count >= 2 else { return }

        let cx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let cy = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        let centroid = CGPoint(x: cx, y: cy)

        lock.lock()
        defer { lock.unlock() }

        if dragPhase == .active {
            endActiveDragUnlocked(reason: "multi-finger")
        } else if dragPhase == .pendingHold {
            dragPhase = .none
        }

        let cursor = CGEvent(source: nil)?.location ?? .zero

        if !multiFinger {
            multiFinger = true
            multiFingerCount = points.count
            multiSwipeFingers = points.count
            multiStartCentroid = centroid
            multiLastCentroid = centroid
            multiMaxTravel = 0
            multiStartY = Float(centroid.y)
            activeTouchID = -2
            touchStartTime = Date()
            touchStartCursor = cursor
            maxVelocity = peakVel
            windowMovePhase = .none
            Log.debug(.tap, "multi-finger begin n=\(points.count) y=\(String(format: "%.2f", multiStartY))")
        } else {
            multiFingerCount = max(multiFingerCount, points.count)
            multiLastCentroid = centroid
            let travel = Float(hypot(centroid.x - multiStartCentroid.x, centroid.y - multiStartCentroid.y))
            // Credit fingers to the swipe only while the chord is still settling. Reading
            // `multiMaxTravel` before this frame's update makes it a latch — it never shrinks,
            // so once the chord has travelled the swipe finger count is final. Same max-then-
            // freeze rule `SwipePinchRecognizer` uses for free-space chords.
            if multiMaxTravel <= thr.swipeMin * 0.5 {
                multiSwipeFingers = max(multiSwipeFingers, points.count)
            }
            if travel > multiMaxTravel { multiMaxTravel = travel }
            if peakVel > maxVelocity { maxVelocity = peakVel }

            // Top-edge 2F + physical mouse move → drag window under cursor.
            if cfg.twoFingerTopEdgeMove,
               multiFingerCount == 2,
               multiStartY >= Self.topEdgeMinY
            {
                let cursorDist = hypot(cursor.x - touchStartCursor.x, cursor.y - touchStartCursor.y)
                if windowMovePhase == .active {
                    // Large finger slide on surface → abandon move, treat as swipe later.
                    if multiMaxTravel > Self.windowMoveMaxSurface * 1.6 {
                        endWindowMoveUnlocked(reason: "surface-swipe")
                    } else {
                        DispatchQueue.main.async {
                            TouchWindowMover.shared.update()
                        }
                    }
                } else if windowMovePhase == .none,
                          cursorDist >= Self.windowMoveCursorMin,
                          multiMaxTravel < Self.windowMoveMaxSurface
                {
                    cancelPendingTwoFingerMiddle()
                    windowMovePhase = .active
                    lastTwoFingerTapTime = nil
                    let haptics = true
                    Log.info(
                        .tap,
                        "→ BEGIN WINDOW MOVE (2F top-edge) " +
                        "cursorDist=\(String(format: "%.1f", cursorDist)) y=\(String(format: "%.2f", multiStartY))"
                    )
                    DispatchQueue.main.async {
                        _ = TouchWindowMover.shared.begin(haptics: haptics)
                    }
                }
            }
        }
    }

    private func killSessionUnlocked(reason: String) {
        if dragPhase == .active {
            endActiveDragUnlocked(reason: "kill:\(reason)")
            suppressUntilLift = true
            suppressedForScroll = (reason == "surface")
            return
        }
        if windowMovePhase == .active {
            endWindowMoveUnlocked(reason: "kill:\(reason)")
            suppressUntilLift = true
            suppressedForScroll = (reason == "surface")
            return
        }
        suppressUntilLift = true
        suppressedForScroll = (reason == "surface")
        pageSwipeActive = false
        activeTouchID = -1
        multiFinger = false
        multiFingerCount = 0
        multiSwipeFingers = 0
        dragPhase = .none
        windowMovePhase = .none
        touchStartX = 0
        touchStartY = 0
        touchStartTime = nil
        touchStartCursor = .zero
        maxSurfaceMove = 0
        maxVelocity = 0
        maxTouchSize = 0
        netDx = 0
        netDy = 0
        multiMaxTravel = 0
        multiStartY = 0
        Log.debug(.tap, "session dead until lift (\(reason))")
    }

    private func endActiveDragUnlocked(reason: String) {
        let point = CGEvent(source: nil)?.location ?? lastDragPostedCursor
        dragPhase = .none
        windowMovePhase = .none
        activeTouchID = -1
        multiFinger = false
        multiFingerCount = 0
        multiSwipeFingers = 0
        touchStartX = 0
        touchStartY = 0
        touchStartTime = nil
        touchStartCursor = .zero
        maxSurfaceMove = 0
        maxVelocity = 0
        maxTouchSize = 0
        netDx = 0
        netDy = 0
        pageSwipeActive = false
        multiMaxTravel = 0
        multiStartY = 0
        suppressUntilLift = false
        suppressedForScroll = false
        lastLeftTapTime = nil
        Log.info(.tap, "→ END DRAG (\(reason))")
        DispatchQueue.main.async {
            ClickEmitter.mouseUp(.left, at: point)
        }
    }

    private func endWindowMoveUnlocked(reason: String) {
        windowMovePhase = .none
        activeTouchID = -1
        multiFinger = false
        multiFingerCount = 0
        multiSwipeFingers = 0
        dragPhase = .none
        touchStartX = 0
        touchStartY = 0
        touchStartTime = nil
        touchStartCursor = .zero
        maxSurfaceMove = 0
        maxVelocity = 0
        maxTouchSize = 0
        netDx = 0
        netDy = 0
        pageSwipeActive = false
        multiMaxTravel = 0
        multiStartY = 0
        suppressUntilLift = false
        suppressedForScroll = false
        Log.info(.tap, "→ END WINDOW MOVE (\(reason))")
        DispatchQueue.main.async {
            TouchWindowMover.shared.end()
        }
    }

    private func finishTap(cfg: MagicMouseTapConfig, reason: String) {
        let thr = Thresholds(sensitivity: cfg.sensitivity)

        lock.lock()
        if dragPhase == .active {
            endActiveDragUnlocked(reason: "finishTap")
            lock.unlock()
            return
        }
        if windowMovePhase == .active {
            endWindowMoveUnlocked(reason: "finishTap")
            lock.unlock()
            return
        }
        let id = activeTouchID
        let multi = multiFinger || id == -2
        let multiCount = multiFingerCount
        let swipeFingers = multiSwipeFingers
        let start = touchStartTime
        let startX = touchStartX
        let startCursor = touchStartCursor
        let surfaceMoved = maxSurfaceMove
        let peakVel = maxVelocity
        let peakSize = maxTouchSize
        let wasPendingDrag = dragPhase == .pendingHold
        let multiTravel = multiMaxTravel
        let multiDx = Float(multiLastCentroid.x - multiStartCentroid.x)
        let multiDy = Float(multiLastCentroid.y - multiStartCentroid.y)
        let startY = multiStartY
        let dx = netDx
        let dy = netDy
        let tapBlocked = start.map { isTapBlockedUnlocked(contactStart: $0) } ?? false
        let physicalOwns = shouldSuppressForPhysicalClickUnlocked()
        resetUnlocked(clearSuppress: true)
        // Keep physicalClickDuringContact cleared for next contact; lastPhysicalClickTime stays
        // briefly so a late finishTap path still suppresses.
        physicalClickDuringContact = false
        lastMouseTouchTime = Date()
        lock.unlock()

        guard id != -1 || multi, let start else { return }

        let duration = Date().timeIntervalSince(start)
        let cursor = CGEvent(source: nil)?.location ?? startCursor
        let cursorDist = hypot(cursor.x - startCursor.x, cursor.y - startCursor.y)

        Log.info(
            .tap,
            "lift (\(reason)) id=\(id) multi=\(multi) multiN=\(multiCount) pendingDrag=\(wasPendingDrag) " +
            "dur=\(String(format: "%.3f", duration)) " +
            "cursorDist=\(String(format: "%.1f", cursorDist)) surface=\(String(format: "%.3f", surfaceMoved)) " +
            "dx=\(String(format: "%.3f", dx)) dy=\(String(format: "%.3f", dy)) " +
            "multiTravel=\(String(format: "%.3f", multiTravel)) vel=\(String(format: "%.3f", peakVel)) " +
            "size=\(String(format: "%.3f", peakSize)) " +
            "x=\(String(format: "%.3f", startX)) sens=\(cfg.sensitivity)" +
            (tapBlocked ? " scrollLock=1" : "") +
            (physicalOwns ? " physical=1" : "")
        )

        if multi {
            // If fingers started on top edge and cursor moved a lot, don't middle-click on lift.
            let cursorMoved = hypot(cursor.x - startCursor.x, cursor.y - startCursor.y)
            if cfg.twoFingerTopEdgeMove,
               multiCount == 2,
               startY >= Self.topEdgeMinY,
               cursorMoved >= Self.windowMoveCursorMin,
               multiTravel < Self.windowMoveMaxSurface
            {
                Log.info(.tap, "→ multi lift after top-edge move attempt (no click)")
                return
            }
            finishMulti(
                cfg: cfg,
                thr: thr,
                duration: duration,
                multiCount: multiCount,
                swipeFingers: swipeFingers,
                travel: multiTravel,
                dx: multiDx,
                dy: multiDy,
                peakVel: peakVel
            )
            return
        }

        // Horizontal page swipe that never crossed mid-gesture threshold still counts on lift.
        // Page swipes are allowed during scroll lock (they're intentional navigation).
        if cfg.oneFingerSwipePages,
           abs(dx) >= thr.pageSwipeMin,
           abs(dx) > abs(dy) * 1.05
        {
            emitPageSwipe(dx: dx)
            return
        }

        // Scroll-session lock: residual finger after scroll is indistinguishable from a tap
        // by surface/duration alone (see sanne.log). BTT/Multitouch suppress clicks for the
        // whole scroll session; we do the same via noTapUntil.
        if tapBlocked {
            // Residuals come in chains (log: rejected residual → second residual clicks
            // right after lock expiry) — extend the lock so the chain stays suppressed.
            lock.lock()
            armNoTapUnlocked(for: Self.residualRepositionLock, reason: "residual-reposition")
            lock.unlock()
            Log.info(
                .tap,
                "→ reject scroll-session lock " +
                "dur=\(String(format: "%.3f", duration)) surface=\(String(format: "%.3f", surfaceMoved))"
            )
            return
        }

        // Physical click already fired via HID — do not synthesize a second click (double-click bug).
        if physicalOwns {
            Log.info(
                .tap,
                "→ reject physical click owns contact " +
                "dur=\(String(format: "%.3f", duration))"
            )
            return
        }

        // Classify at lift. Stationary finger = tap; vertical slide = scroll.
        if surfaceMoved >= thr.surfaceScroll {
            Log.info(
                .tap,
                "→ reject surface \(String(format: "%.3f", surfaceMoved)) ≥ \(String(format: "%.3f", thr.surfaceScroll)) " +
                "(vel peak \(String(format: "%.3f", peakVel)) ignored)"
            )
            return
        }
        if duration >= thr.maxDuration {
            Log.info(.tap, "→ reject duration \(String(format: "%.3f", duration)) ≥ \(String(format: "%.3f", thr.maxDuration)) (rest)")
            return
        }
        if duration < thr.minDuration {
            Log.info(.tap, "→ reject duration \(String(format: "%.3f", duration)) < \(String(format: "%.3f", thr.minDuration)) (graze)")
            return
        }
        if peakSize > 0, peakSize < Self.minTouchSize {
            Log.info(.tap, "→ reject size \(String(format: "%.3f", peakSize)) < \(String(format: "%.3f", Self.minTouchSize)) (graze)")
            return
        }
        if cursorDist >= thr.cursorMove {
            Log.info(.tap, "→ reject cursor \(String(format: "%.1f", cursorDist)) ≥ \(String(format: "%.0f", thr.cursorMove))")
            return
        }

        let split = Float(cfg.leftRightSplit)
        let dead = Float(cfg.deadZone)
        let rightMin = split + dead / 2

        if startX >= rightMin, cfg.rightTap {
            emitClick(.right, cfg: cfg, cursor: cursor)
        } else if cfg.leftTap {
            lock.lock()
            lastLeftTapTime = Date()
            lock.unlock()
            emitClick(.left, cfg: cfg, cursor: cursor)
        }
    }

    private func finishMulti(
        cfg: MagicMouseTapConfig,
        thr: Thresholds,
        duration: TimeInterval,
        multiCount: Int,
        swipeFingers: Int,
        travel: Float,
        dx: Float,
        dy: Float,
        peakVel: Float
    ) {
        // Prefer swipe if travel past threshold. Every path below returns — including the ones
        // where the matching toggle is off — because falling through would let a 3-finger swipe
        // fire the 2-finger slots, which is the bug this branch exists to prevent. Returning is
        // also what keeps a 3-finger *swipe* from firing the 3-finger middle-click further down:
        // the two are the same chord and `swipeMin` is the only thing separating them.
        if travel >= thr.swipeMin {
            // A committed swipe supersedes a 2-finger middle-click still waiting out its
            // double-tap window — same rule as a window move or a 3-finger middle-click —
            // otherwise the delayed click lands mid-swipe. `finishTap` released the lock
            // before calling us, matching the unlocked access in the branches below.
            // Armed in the `isTwo` path below.
            cancelPendingTwoFingerMiddle()
            lastTwoFingerTapTime = nil
            let axis = Self.swipeAxis(dx: dx, dy: dy)
            // Frozen count, not the running max: a finger grazing the shell mid-swipe must not
            // promote a 2-finger swipe into the 3-finger slots.
            if let slotId = Self.swipeSlot(fingers: swipeFingers, axis: axis, cfg: cfg) {
                Log.info(
                    .tap,
                    "→ \(swipeFingers)F SWIPE \(axis.rawValue.uppercased()) slot=\(slotId) " +
                    "travel=\(String(format: "%.3f", travel))"
                )
                emit(.recognized(slotId: slotId, clickCount: 1))
            } else {
                Log.debug(
                    .tap,
                    "multi swipe ignored (toggle off) \(swipeFingers)F \(axis.rawValue) " +
                    "travel=\(String(format: "%.3f", travel))"
                )
            }
            return
        }

        // Stationary multi-finger touch → middle-click or 2F double-tap Mission Control.
        // Reachable only when travel < swipeMin (see above), so a middle-click here is by
        // definition a chord that stayed put.
        guard duration < thr.maxDuration * 1.25 else {
            Log.info(.tap, "→ multi reject duration \(String(format: "%.3f", duration))")
            return
        }
        _ = peakVel // peak vel unused for multi-tap (noisy)

        let isTwo = multiCount == 2
        let isThreePlus = multiCount >= 3

        if isThreePlus, cfg.middleThreeFinger {
            cancelPendingTwoFingerMiddle()
            Log.info(.tap, "→ MIDDLE (3-finger)")
            emit(.recognized(slotId: GestureSlots.ID.mmMiddle3, clickCount: 1))
            return
        }

        if isTwo {
            // Second 2F tap within window → Mission Control (cancel delayed middle).
            if cfg.twoFingerDoubleTapMissionControl,
               let last = lastTwoFingerTapTime,
               Date().timeIntervalSince(last) < Self.twoFingerDoubleWindow
            {
                cancelPendingTwoFingerMiddle()
                lastTwoFingerTapTime = nil
                Log.info(.tap, "→ 2F DOUBLE TAP Mission Control")
                emit(.recognized(slotId: GestureSlots.ID.mm2fDoubleMC, clickCount: 1))
                return
            }

            if cfg.twoFingerDoubleTapMissionControl, cfg.middleTwoFinger {
                // Delay middle so a quick double-tap can become Mission Control instead.
                lastTwoFingerTapTime = Date()
                cancelPendingTwoFingerMiddle()
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.lock.lock()
                    self.lastTwoFingerTapTime = nil
                    self.pendingTwoFingerMiddleWorkItem = nil
                    self.lock.unlock()
                    Log.info(.tap, "→ MIDDLE (2-finger, after double-tap window)")
                    self.emit(.recognized(slotId: GestureSlots.ID.mmMiddle2, clickCount: 1))
                }
                pendingTwoFingerMiddleWorkItem = work
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Self.twoFingerDoubleWindow,
                    execute: work
                )
                Log.debug(.tap, "2F tap armed — middle in \(Self.twoFingerDoubleWindow)s unless double")
                return
            }

            if cfg.middleTwoFinger {
                Log.info(.tap, "→ MIDDLE (2-finger)")
                emit(.recognized(slotId: GestureSlots.ID.mmMiddle2, clickCount: 1))
                return
            }

            if cfg.twoFingerDoubleTapMissionControl {
                lastTwoFingerTapTime = Date()
                Log.debug(.tap, "2F tap armed for Mission Control double")
            }
        }
    }

    /// Dominant axis of a multi-finger swipe. Ties go vertical, matching the original
    /// `ady >= adx` test.
    private enum SwipeAxis: String {
        case up, down, left, right
    }

    /// Norm Y increases toward the top of the mouse, so `dy > 0` is an upward swipe.
    private static func swipeAxis(dx: Float, dy: Float) -> SwipeAxis {
        if abs(dy) >= abs(dx) {
            return dy > 0 ? .up : .down
        }
        return dx < 0 ? .left : .right
    }

    /// Slot for a committed multi-finger swipe, or nil when the owning toggle is off.
    ///
    /// 3+ contacts pick the 3-finger family: the spare fingers rest on the shell, so a
    /// deliberate 3-finger swipe often reports 4 contacts.
    private static func swipeSlot(
        fingers: Int,
        axis: SwipeAxis,
        cfg: MagicMouseTapConfig
    ) -> String? {
        if fingers >= 3 {
            guard cfg.threeFingerSwipes else { return nil }
            switch axis {
            case .up: return GestureSlots.ID.mm3fSwipeUp
            case .down: return GestureSlots.ID.mm3fSwipeDown
            case .left: return GestureSlots.ID.mm3fSwipeLeft
            case .right: return GestureSlots.ID.mm3fSwipeRight
            }
        }
        switch axis {
        case .up:
            return cfg.twoFingerSwipeUpMissionControl ? GestureSlots.ID.mm2fSwipeUp : nil
        case .down:
            return cfg.twoFingerSwipeDownAppExpose ? GestureSlots.ID.mm2fSwipeDown : nil
        case .left:
            return cfg.twoFingerSwipeSpaces ? GestureSlots.ID.mm2fSwipeLeft : nil
        case .right:
            return cfg.twoFingerSwipeSpaces ? GestureSlots.ID.mm2fSwipeRight : nil
        }
    }

    private func cancelPendingTwoFingerMiddle() {
        pendingTwoFingerMiddleWorkItem?.cancel()
        pendingTwoFingerMiddleWorkItem = nil
    }

    private func emitClick(_ button: ClickButton, cfg: MagicMouseTapConfig, cursor: CGPoint) {
        var count = 1
        if cfg.multiClick {
            let now = Date()
            if let lastT = lastClickTime,
               let lastB = lastClickButton,
               lastB == button,
               now.timeIntervalSince(lastT) < Self.multiClickWindow,
               hypot(cursor.x - lastClickCursor.x, cursor.y - lastClickCursor.y) < Self.multiClickMaxCursorDist
            {
                count = min(3, lastClickCount + 1)
            }
            lastClickTime = now
            lastClickButton = button
            lastClickCount = count
            lastClickCursor = cursor
        }
        let label: String
        switch button {
        case .left: label = "LEFT"
        case .right: label = "RIGHT"
        case .middle: label = "MIDDLE"
        }
        let slotId: String
        switch button {
        case .left: slotId = GestureSlots.ID.mmLeft
        case .right: slotId = GestureSlots.ID.mmRight
        case .middle: slotId = GestureSlots.ID.mmMiddle2
        }
        Log.info(.tap, "→ \(label)×\(count) slot=\(slotId)")
        // ClickEmitter will post shortly on main; ignore the local-monitor echo.
        lock.lock()
        armSyntheticEchoIgnoreUnlocked()
        lock.unlock()
        emit(.recognized(slotId: slotId, clickCount: count))
    }

    private func emit(_ event: MagicMouseEvent) {
        DispatchQueue.main.async { self.onEvent?(event) }
    }

    /// Map finger travel to page navigation matching macOS natural swipe-between-pages.
    /// Finger moves right (dx > 0) → back; finger moves left (dx < 0) → forward.
    private func emitPageSwipe(dx: Float) {
        if dx > 0 {
            Log.info(.tap, "→ 1F SWIPE RIGHT back dx=\(String(format: "%.3f", dx))")
            emit(.recognized(slotId: GestureSlots.ID.mm1fSwipeRight, clickCount: 1))
        } else {
            Log.info(.tap, "→ 1F SWIPE LEFT forward dx=\(String(format: "%.3f", dx))")
            emit(.recognized(slotId: GestureSlots.ID.mm1fSwipeLeft, clickCount: 1))
        }
    }

    private func resetUnlocked(clearSuppress: Bool) {
        activeTouchID = -1
        multiFinger = false
        multiFingerCount = 0
        multiSwipeFingers = 0
        dragPhase = .none
        windowMovePhase = .none
        touchStartX = 0
        touchStartY = 0
        touchStartTime = nil
        touchStartCursor = .zero
        maxSurfaceMove = 0
        maxVelocity = 0
        maxTouchSize = 0
        netDx = 0
        netDy = 0
        pageSwipeActive = false
        multiMaxTravel = 0
        multiStartY = 0
        multiStartCentroid = .zero
        multiLastCentroid = .zero
        // physicalClickDuringContact / lastPhysicalClickTime are managed by finishTap /
        // notePhysicalMouseDown / touch-begin so a late physical press still suppresses.
        if clearSuppress {
            suppressUntilLift = false
        }
    }

    var stats: String {
        lock.lock(); defer { lock.unlock() }
        return "mmStarted=\(started) mmDevices=\(devices.count) mmCallbacks=\(callbackCount)"
    }
}
