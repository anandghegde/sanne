import AppKit
import CoreGraphics
import Foundation

/// High-level Magic Mouse recognizer output (taps + multi-finger gestures).
enum MagicMouseEvent: Equatable {
    case recognized(slotId: String, clickCount: Int)
}

/// Magic Mouse surface gestures. Device registration lives on `TouchDeviceManager`.
final class MagicMouseTapController: @unchecked Sendable {
    static let shared = MagicMouseTapController()

    private let lock = NSLock()
    private var started = false
    private var onEvent: ((MagicMouseEvent) -> Void)?
    private var snapshot = RuntimeSnapshot.empty
    private var session = MMSession()
    private var scrollLock = ScrollLock()
    private var physicalGuard = PhysicalClickGuard()
    private var callbackCount = 0
    private var scrollWheelMonitor: Any?
    private var mouseClickGlobalMonitor: Any?
    private var mouseClickLocalMonitor: Any?
    private var pendingTwoFingerMiddleWorkItem: DispatchWorkItem?
    private var windowMoveUpdateQueued = false

    func start(onEvent: @escaping (MagicMouseEvent) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.onEvent = onEvent
        refreshSnapshotUnlocked()
        NotificationCenter.default.addObserver(
            forName: .sanneRuntimeSnapshotDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshSnapshotFromStore()
        }
        if started {
            Log.info(.tap, "MagicMouseTap already started")
            return
        }
        started = true
        callbackCount = 0
        scrollLock = ScrollLock()
        physicalGuard = PhysicalClickGuard()
        startScrollWheelMonitorUnlocked()
        startMouseClickMonitorUnlocked()
        Log.info(.tap, "MagicMouseTap RUNNING (devices owned by TouchDeviceManager). Tap the mouse surface.")
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }
        started = false
        stopScrollWheelMonitorUnlocked()
        stopMouseClickMonitorUnlocked()
        cancelPendingTwoFingerMiddle()
        session.reset(clearSuppress: true)
        scrollLock = ScrollLock()
        physicalGuard = PhysicalClickGuard()
        session.suppressedForScroll = false
        session.pageSwipeActive = false
        session.lastMouseTouchTime = nil
        MainHop.async { WindowMover.shared.end() }
        Log.info(.tap, "MagicMouseTap stopped callbacks=\(callbackCount)")
    }

    func restart() {
        let event = onEvent
        stop()
        guard let event else {
            Log.warn(.tap, "MagicMouseTap restart skipped — never started")
            return
        }
        start(onEvent: event)
    }

    var monitoredDeviceCount: Int {
        TouchDeviceManager.shared.magicMouseDeviceCount
    }

    var stats: String {
        lock.lock(); defer { lock.unlock() }
        return "mmStarted=\(started) mmDevices=\(TouchDeviceManager.shared.magicMouseDeviceCount) mmCallbacks=\(callbackCount)"
    }

    func handleRaw(
        device: Int32,
        touches: UnsafeMutableRawPointer?,
        numTouches: Int,
        timestamp: Double,
        frame: Int32
    ) {
        PerfCounters.incMMCallbacks()
        lock.lock()
        callbackCount += 1
        let n = callbackCount
        let snap = snapshot
        let running = started
        lock.unlock()
        guard running else { return }
        if !snap.masters.magicMouse || snap.pauseMagicMouse { return }

        if LogRing.shared.shouldLogTouchFrame() {
            Log.debug(.tap, "cb#\(n) device=\(device) num=\(numTouches) frame=\(frame)")
        }

        if numTouches <= 0 {
            handleLift(snap: snap)
            return
        }

        lock.lock()
        let suppressed = session.suppressUntilLift
        lock.unlock()
        if suppressed { return }

        guard let touches else {
            Log.warn(.tap, "cb#\(n) nil touches ptr")
            return
        }

        var contactIndices: [Int] = []
        for i in 0..<numTouches where PrivateMT.isPhysicalContact(PrivateMT.touch(at: touches, index: i).state) {
            contactIndices.append(i)
        }
        if contactIndices.isEmpty { return }

        if contactIndices.count >= 2 {
            handleMultiFinger(touches: touches, numTouches: numTouches, snap: snap)
            return
        }

        handleSingle(touch: PrivateMT.touch(at: touches, index: contactIndices[0]), snap: snap)
    }

    // MARK: Snapshot

    private func refreshSnapshotFromStore() {
        let next = RuntimeSnapshotStore.shared.snapshot
        lock.lock()
        snapshot = next
        lock.unlock()
    }

    private func refreshSnapshotUnlocked() {
        snapshot = RuntimeSnapshotStore.shared.snapshot
    }

    // MARK: Single finger

    private func handleSingle(touch t: MTTouchC, snap: RuntimeSnapshot) {
        let nx = t.normX
        let ny = t.normY
        let identifier = t.identifier
        let speed = hypot(t.velX, t.velY)
        let thr = MMThresholds(sensitivity: snap.mmSensitivity)
        let cursor = CursorLocation.current()
        let now = CFAbsoluteTimeGetCurrent()

        if LogRing.shared.shouldLogTouchFrame() {
            Log.debug(
                .tap,
                "  id=\(identifier) state=\(t.state) " +
                "xy=(\(String(format: "%.3f", nx)),\(String(format: "%.3f", ny))) " +
                "vel=\(String(format: "%.3f", speed))"
            )
        }

        lock.lock()
        defer { lock.unlock() }

        if session.multiFinger { return }

        if session.activeTouchID < 0 {
            session.activeTouchID = identifier
            session.touchStartX = nx
            session.touchStartY = ny
            session.touchStartTime = now
            session.touchStartCursor = cursor
            session.maxSurfaceMove = 0
            session.maxVelocity = speed
            session.maxTouchSize = t.size
            session.netDx = 0
            session.netDy = 0
            session.pageSwipeActive = false
            physicalGuard.clearContactFlag()
            session.lastMouseTouchTime = now

            let blocked = scrollLock.isBlocked(contactStart: now)
            if MMDragSession.shouldArmPending(
                snapshot: snap,
                blocked: blocked,
                lastLeftTap: session.lastLeftTapTime,
                now: now
            ) {
                session.dragPhase = .pendingHold
                session.lastLeftTapTime = nil
                Log.debug(.tap, "drag pendingHold (double-tap window)")
            } else {
                session.dragPhase = .none
            }
            Log.info(
                .tap,
                "touch began id=\(identifier) surface=(\(String(format: "%.3f", nx)),\(String(format: "%.3f", ny))) " +
                "sens=\(snap.mmSensitivity) drag=\(session.dragPhase.rawValue)" +
                (blocked ? " scrollLock=1" : "")
            )
            return
        }

        if session.activeTouchID != identifier {
            session.activeTouchID = identifier
        }

        session.netDx = nx - session.touchStartX
        session.netDy = ny - session.touchStartY
        let surfaceMove = max(abs(session.netDx), abs(session.netDy))
        if surfaceMove > session.maxSurfaceMove { session.maxSurfaceMove = surfaceMove }
        if speed > session.maxVelocity { session.maxVelocity = speed }
        if t.size > session.maxTouchSize { session.maxTouchSize = t.size }

        if session.dragPhase == .active {
            let dist = hypot(cursor.x - session.lastDragPostedCursor.x, cursor.y - session.lastDragPostedCursor.y)
            if dist >= 1.0 {
                session.lastDragPostedCursor = cursor
                ClickEmitter.mouseDragged(.left, at: cursor)
            }
            return
        }

        if session.pageSwipeActive {
            if session.dragPhase == .pendingHold { session.dragPhase = .none }
            return
        }

        if surfaceMove > thr.surfaceScroll {
            let adx = abs(session.netDx)
            let ady = abs(session.netDy)
            if (snap.slotOn(GestureSlots.ID.mm1fSwipeLeft) || snap.slotOn(GestureSlots.ID.mm1fSwipeRight)),
               adx > ady * 1.05
            {
                session.pageSwipeActive = true
                if session.dragPhase == .pendingHold { session.dragPhase = .none }
                Log.debug(.tap, "page swipe track dx=\(String(format: "%.3f", session.netDx))")
                return
            }
            Log.debug(.tap, "cancel: surface scroll")
            armNoTapUnlocked(for: ScrollLock.surface, reason: "surface-scroll")
            applyKill("surface")
            return
        }

        let cursorDist = hypot(cursor.x - session.touchStartCursor.x, cursor.y - session.touchStartCursor.y)
        if cursorDist > thr.cursorMove {
            Log.debug(.tap, "cancel: cursor")
            applyKill("cursor")
            return
        }

        if session.dragPhase == .pendingHold, let start = session.touchStartTime {
            switch MMDragSession.tickHold(snapshot: snap, start: start, now: now) {
            case .none:
                break
            case .beginDrag:
                session.lastClickTime = nil
                session.lastClickCount = 0
                session.dragPhase = .active
                session.lastDragPostedCursor = cursor
                Log.info(.tap, "→ BEGIN DRAG")
                physicalGuard.armSyntheticEcho()
                ClickEmitter.mouseDown(.left, at: cursor)
            case .fireRemap:
                session.dragPhase = .none
                session.suppressUntilLift = true
                Log.info(.tap, "→ DOUBLE-TAP HOLD remap")
                emit(.recognized(slotId: GestureSlots.ID.mmDrag, clickCount: 1))
            case .cancel:
                session.dragPhase = .none
            }
        }
    }

    // MARK: Multi finger

    private func handleMultiFinger(touches: UnsafeMutableRawPointer, numTouches: Int, snap: RuntimeSnapshot) {
        let thr = MMThresholds(sensitivity: snap.mmSensitivity)
        var points: [CGPoint] = []
        var peakVel: Float = 0
        for i in 0..<numTouches {
            let t = PrivateMT.touch(at: touches, index: i)
            guard PrivateMT.isPhysicalContact(t.state) else { continue }
            points.append(CGPoint(x: CGFloat(t.normX), y: CGFloat(t.normY)))
            peakVel = max(peakVel, hypot(t.velX, t.velY))
        }
        guard points.count >= 2 else { return }

        let cx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let cy = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        let centroid = CGPoint(x: cx, y: cy)
        let cursor = CursorLocation.current()
        let now = CFAbsoluteTimeGetCurrent()

        lock.lock()
        defer { lock.unlock() }

        if session.dragPhase == .active {
            endActiveDragUnlocked(reason: "multi-finger")
        } else if session.dragPhase == .pendingHold {
            session.dragPhase = .none
        }

        if !session.multiFinger {
            session.multiFinger = true
            session.multiFingerCount = points.count
            session.multiSwipeFingers = points.count
            session.multiStartCentroid = centroid
            session.multiLastCentroid = centroid
            session.multiMaxTravel = 0
            session.multiStartY = Float(centroid.y)
            session.activeTouchID = -2
            session.touchStartTime = now
            session.touchStartCursor = cursor
            session.maxVelocity = peakVel
            session.windowMovePhase = .none
            Log.debug(.tap, "multi-finger begin n=\(points.count) y=\(String(format: "%.2f", session.multiStartY))")
        } else {
            session.multiFingerCount = max(session.multiFingerCount, points.count)
            session.multiLastCentroid = centroid
            let travel = Float(hypot(centroid.x - session.multiStartCentroid.x, centroid.y - session.multiStartCentroid.y))
            session.multiSwipeFingers = MMSwipeMachine.creditFingers(
                current: session.multiSwipeFingers,
                reported: points.count,
                maxTravel: session.multiMaxTravel,
                swipeMin: thr.swipeMin
            )
            if travel > session.multiMaxTravel { session.multiMaxTravel = travel }
            if peakVel > session.maxVelocity { session.maxVelocity = peakVel }

            if let kind = MMWindowMove.kind(fingerCount: session.multiFingerCount, snapshot: snap),
               session.multiStartY >= MMWindowMove.topEdgeMinY
            {
                let cursorDist = hypot(cursor.x - session.touchStartCursor.x, cursor.y - session.touchStartCursor.y)
                if session.windowMovePhase == .active {
                    if MMWindowMove.shouldAbandonForSwipe(travel: session.multiMaxTravel) {
                        endWindowMoveUnlocked(reason: "surface-swipe")
                    } else {
                        queueWindowMoveUpdate()
                    }
                } else if session.windowMovePhase == .none,
                          MMWindowMove.shouldBegin(
                            cursorDist: cursorDist,
                            travel: session.multiMaxTravel,
                            startY: session.multiStartY
                          )
                {
                    cancelPendingTwoFingerMiddle()
                    session.windowMovePhase = .active
                    session.windowMoveKind = kind
                    session.lastTwoFingerTapTime = nil
                    Log.info(.tap, "→ BEGIN WINDOW \(kind == .resize ? "RESIZE" : "MOVE")")
                    MainHop.async { _ = WindowMover.shared.begin(kind: kind, haptics: true) }
                }
            }
        }
    }

    // MARK: Lift

    private func handleLift(snap: RuntimeSnapshot) {
        lock.lock()
        let phase = session.dragPhase
        let suppressed = session.suppressUntilLift
        let wasScroll = session.suppressedForScroll
        let pageSwipe = session.pageSwipeActive
        let swipeDx = session.netDx
        if pageSwipe {
            let thr = MMThresholds(sensitivity: snap.mmSensitivity)
            let dx = swipeDx
            session.reset(clearSuppress: true)
            session.pageSwipeActive = false
            session.suppressedForScroll = false
            lock.unlock()
            if (snap.slotOn(GestureSlots.ID.mm1fSwipeLeft) || snap.slotOn(GestureSlots.ID.mm1fSwipeRight)),
               abs(dx) >= thr.pageSwipeMin
            {
                emitPageSwipe(dx: dx)
            } else {
                Log.debug(.tap, "page swipe too short dx=\(String(format: "%.3f", dx))")
            }
            return
        }
        if suppressed {
            if wasScroll {
                armNoTapUnlocked(for: ScrollLock.surface, reason: "surface-scroll-lift")
            }
            session.lastMouseTouchTime = CFAbsoluteTimeGetCurrent()
            Log.debug(.tap, "lift while suppressed — no click")
            session.reset(clearSuppress: true)
            session.suppressedForScroll = false
            lock.unlock()
            return
        }
        if phase == .active {
            endActiveDragUnlocked(reason: "lift")
            lock.unlock()
            return
        }
        if session.windowMovePhase == .active {
            endWindowMoveUnlocked(reason: "lift")
            lock.unlock()
            return
        }
        lock.unlock()
        finishTap(snap: snap)
    }

    private func finishTap(snap: RuntimeSnapshot) {
        let thr = MMThresholds(sensitivity: snap.mmSensitivity)
        lock.lock()
        if session.dragPhase == .active {
            endActiveDragUnlocked(reason: "finishTap")
            lock.unlock()
            return
        }
        if session.windowMovePhase == .active {
            endWindowMoveUnlocked(reason: "finishTap")
            lock.unlock()
            return
        }
        let id = session.activeTouchID
        let multi = session.multiFinger || id == -2
        let multiCount = session.multiFingerCount
        let swipeFingers = session.multiSwipeFingers
        let start = session.touchStartTime
        let startX = session.touchStartX
        let startCursor = session.touchStartCursor
        let surfaceMoved = session.maxSurfaceMove
        let peakVel = session.maxVelocity
        let peakSize = session.maxTouchSize
        let multiTravel = session.multiMaxTravel
        let multiDx = Float(session.multiLastCentroid.x - session.multiStartCentroid.x)
        let multiDy = Float(session.multiLastCentroid.y - session.multiStartCentroid.y)
        let startY = session.multiStartY
        let dx = session.netDx
        let dy = session.netDy
        let tapBlocked = start.map { scrollLock.isBlocked(contactStart: $0) } ?? false
        let physicalOwns = physicalGuard.shouldSuppress()
        let rightHeld = session.physicalRightHeld
        session.reset(clearSuppress: true)
        physicalGuard.clearContactFlag()
        session.lastMouseTouchTime = CFAbsoluteTimeGetCurrent()
        lock.unlock()

        guard id != -1 || multi, let start else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let duration = now - start
        let cursor = CursorLocation.current()
        let cursorDist = hypot(cursor.x - startCursor.x, cursor.y - startCursor.y)

        Log.debug(
            .tap,
            "lift id=\(id) multi=\(multi) multiN=\(multiCount) " +
            "dur=\(String(format: "%.3f", duration)) " +
            "surface=\(String(format: "%.3f", surfaceMoved))"
        )

        if multi {
            if startY >= MMWindowMove.topEdgeMinY,
               hypot(cursor.x - startCursor.x, cursor.y - startCursor.y) >= MMWindowMove.cursorMin,
               multiTravel < MMWindowMove.maxSurface,
               MMWindowMove.kind(fingerCount: multiCount, snapshot: snap) != nil
            {
                Log.info(.tap, "→ multi lift after top-edge move/resize attempt (no click)")
                return
            }
            finishMulti(
                snap: snap,
                thr: thr,
                duration: duration,
                multiCount: multiCount,
                swipeFingers: swipeFingers,
                travel: multiTravel,
                dx: multiDx,
                dy: multiDy
            )
            return
        }

        switch MMTapMachine.decideLift(
            snapshot: snap,
            duration: duration,
            surfaceMoved: surfaceMoved,
            peakVel: peakVel,
            peakSize: peakSize,
            cursorDist: cursorDist,
            startX: startX,
            dx: dx,
            dy: dy,
            tapBlocked: tapBlocked,
            physicalOwns: physicalOwns,
            rightHeld: rightHeld,
            thr: thr
        ) {
        case .pageSwipe(let swipeDx):
            emitPageSwipe(dx: swipeDx)
        case .reject(let reason):
            if reason == "scroll-session lock" {
                lock.lock()
                armNoTapUnlocked(for: ScrollLock.residual, reason: "residual-reposition")
                lock.unlock()
            }
            Log.debug(.tap, "→ reject \(reason)")
        case .deadZone:
            Log.info(.tap, "→ reject dead zone x=\(String(format: "%.3f", startX))")
        case .click(let button):
            if button == .left {
                lock.lock()
                session.lastLeftTapTime = now
                lock.unlock()
            }
            emitClick(button, snap: snap, cursor: cursor, now: now)
        }
    }

    private func finishMulti(
        snap: RuntimeSnapshot,
        thr: MMThresholds,
        duration: TimeInterval,
        multiCount: Int,
        swipeFingers: Int,
        travel: Float,
        dx: Float,
        dy: Float
    ) {
        if travel >= thr.swipeMin {
            cancelPendingTwoFingerMiddle()
            session.lastTwoFingerTapTime = nil
            let axis = MMGeometry.swipeAxis(dx: dx, dy: dy)
            if let slotId = MMSwipeMachine.enabledSlot(fingers: swipeFingers, axis: axis, snapshot: snap) {
                Log.info(.tap, "→ \(swipeFingers)F SWIPE \(axis.rawValue.uppercased()) slot=\(slotId)")
                emit(.recognized(slotId: slotId, clickCount: 1))
            } else {
                Log.debug(.tap, "multi swipe ignored (toggle off) \(swipeFingers)F \(axis.rawValue)")
            }
            return
        }

        guard duration < thr.maxDuration * 1.25 else {
            Log.debug(.tap, "→ multi reject duration")
            return
        }

        let isTwo = multiCount == 2
        let isThreePlus = multiCount >= 3
        let now = CFAbsoluteTimeGetCurrent()

        if isThreePlus, snap.slotOn(GestureSlots.ID.mmMiddle3) {
            cancelPendingTwoFingerMiddle()
            Log.info(.tap, "→ MIDDLE (3-finger)")
            emit(.recognized(slotId: GestureSlots.ID.mmMiddle3, clickCount: 1))
            return
        }

        if isTwo {
            if snap.slotOn(GestureSlots.ID.mm2fDoubleMC),
               let last = session.lastTwoFingerTapTime,
               now - last < 0.32
            {
                cancelPendingTwoFingerMiddle()
                session.lastTwoFingerTapTime = nil
                Log.info(.tap, "→ 2F DOUBLE TAP Mission Control")
                emit(.recognized(slotId: GestureSlots.ID.mm2fDoubleMC, clickCount: 1))
                return
            }

            if snap.slotOn(GestureSlots.ID.mm2fDoubleMC), snap.slotOn(GestureSlots.ID.mmMiddle2) {
                session.lastTwoFingerTapTime = now
                cancelPendingTwoFingerMiddle()
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.lock.lock()
                    self.session.lastTwoFingerTapTime = nil
                    self.pendingTwoFingerMiddleWorkItem = nil
                    self.lock.unlock()
                    Log.info(.tap, "→ MIDDLE (2-finger, after double-tap window)")
                    self.emit(.recognized(slotId: GestureSlots.ID.mmMiddle2, clickCount: 1))
                }
                pendingTwoFingerMiddleWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
                Log.debug(.tap, "2F tap armed — middle in 0.32s unless double")
                return
            }

            if snap.slotOn(GestureSlots.ID.mmMiddle2) {
                Log.info(.tap, "→ MIDDLE (2-finger)")
                emit(.recognized(slotId: GestureSlots.ID.mmMiddle2, clickCount: 1))
                return
            }

            if snap.slotOn(GestureSlots.ID.mm2fDoubleMC) {
                session.lastTwoFingerTapTime = now
            }
        }
    }

    // MARK: Side effects

    private func applyKill(_ reason: String) {
        switch session.kill(reason: reason) {
        case .endDrag: endActiveDragUnlocked(reason: "kill:\(reason)")
        case .endWindowMove: endWindowMoveUnlocked(reason: "kill:\(reason)")
        case .none: break
        }
        Log.debug(.tap, "session dead until lift (\(reason))")
    }

    private func endActiveDragUnlocked(reason: String) {
        let point = CursorLocation.current()
        session.reset(clearSuppress: true)
        session.lastLeftTapTime = nil
        Log.info(.tap, "→ END DRAG (\(reason))")
        ClickEmitter.mouseUp(.left, at: point)
    }

    private func endWindowMoveUnlocked(reason: String) {
        session.reset(clearSuppress: true)
        Log.info(.tap, "→ END WINDOW MOVE (\(reason))")
        MainHop.async { WindowMover.shared.end() }
    }

    private func queueWindowMoveUpdate() {
        if windowMoveUpdateQueued { return }
        windowMoveUpdateQueued = true
        MainHop.async { [weak self] in
            self?.lock.lock()
            self?.windowMoveUpdateQueued = false
            self?.lock.unlock()
            WindowMover.shared.update()
        }
    }

    private func armNoTapUnlocked(for duration: TimeInterval, reason: String) {
        scrollLock.arm(for: duration)
        Log.debug(.tap, "no-tap until +\(String(format: "%.2f", duration))s (\(reason))")
    }

    private func cancelPendingTwoFingerMiddle() {
        pendingTwoFingerMiddleWorkItem?.cancel()
        pendingTwoFingerMiddleWorkItem = nil
    }

    private func emitClick(_ button: ClickButton, snap: RuntimeSnapshot, cursor: CGPoint, now: TimeInterval) {
        lock.lock()
        let count = MMTapMachine.nextClickCount(
            button: button,
            cursor: cursor,
            multiClick: snap.multiClick,
            lastTime: session.lastClickTime,
            lastButton: session.lastClickButton,
            lastCount: session.lastClickCount,
            lastCursor: session.lastClickCursor,
            now: now
        )
        session.lastClickTime = now
        session.lastClickButton = button
        session.lastClickCount = count
        session.lastClickCursor = cursor
        physicalGuard.armSyntheticEcho()
        lock.unlock()
        let slotId = button == .left ? GestureSlots.ID.mmLeft : GestureSlots.ID.mmRight
        Log.info(.tap, "→ \(button)×\(count) slot=\(slotId)")
        emit(.recognized(slotId: slotId, clickCount: count))
    }

    private func emit(_ event: MagicMouseEvent) {
        onEvent?(event)
    }

    private func emitPageSwipe(dx: Float) {
        if dx > 0 {
            Log.info(.tap, "→ 1F SWIPE RIGHT back dx=\(String(format: "%.3f", dx))")
            emit(.recognized(slotId: GestureSlots.ID.mm1fSwipeRight, clickCount: 1))
        } else {
            Log.info(.tap, "→ 1F SWIPE LEFT forward dx=\(String(format: "%.3f", dx))")
            emit(.recognized(slotId: GestureSlots.ID.mm1fSwipeLeft, clickCount: 1))
        }
    }

    // MARK: Monitors

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
        }
    }

    private func stopScrollWheelMonitorUnlocked() {
        if let mon = scrollWheelMonitor {
            scrollWheelMonitor = nil
            DispatchQueue.main.async { NSEvent.removeMonitor(mon) }
        }
    }

    private func noteScrollWheel(_ event: NSEvent) {
        let dy = abs(event.scrollingDeltaY)
        let dx = abs(event.scrollingDeltaX)
        guard dy >= ScrollLock.wheelDeltaMin || dx >= ScrollLock.wheelDeltaMin else { return }
        lock.lock()
        let recentTouch: Bool = {
            guard let t = session.lastMouseTouchTime else { return false }
            return CFAbsoluteTimeGetCurrent() - t < ScrollLock.wheelTouchCorrelation
        }()
        if recentTouch {
            let isMomentum = !event.momentumPhase.isEmpty
            armNoTapUnlocked(for: isMomentum ? ScrollLock.momentum : ScrollLock.wheel, reason: isMomentum ? "wheel-momentum" : "wheel")
        }
        lock.unlock()
    }

    private func startMouseClickMonitorUnlocked() {
        guard mouseClickGlobalMonitor == nil, mouseClickLocalMonitor == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            guard self.started, self.mouseClickGlobalMonitor == nil else { return }
            let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .rightMouseUp]
            self.mouseClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                self?.notePhysicalMouse(event)
            }
            self.mouseClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                self?.notePhysicalMouse(event)
                return event
            }
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

    private func notePhysicalMouse(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard started else { return }

        if event.type == .rightMouseDown {
            session.physicalRightHeld = true
        } else if event.type == .rightMouseUp {
            session.physicalRightHeld = false
        }

        guard event.type == .leftMouseDown || event.type == .rightMouseDown else { return }
        if physicalGuard.shouldIgnoreEcho() { return }

        let activeSingle = session.activeTouchID >= 0 && !session.multiFinger
        let recentTouch: Bool = {
            guard let t = session.lastMouseTouchTime else { return false }
            return CFAbsoluteTimeGetCurrent() - t < PhysicalClickGuard.suppressWindow
        }()
        let pendingDrag = session.dragPhase == .pendingHold
        guard activeSingle || recentTouch || pendingDrag else { return }

        physicalGuard.notePhysicalClick()
        if session.dragPhase == .pendingHold {
            session.dragPhase = .none
        }
        Log.debug(.tap, "physical click — suppress synthetic")
    }
}
