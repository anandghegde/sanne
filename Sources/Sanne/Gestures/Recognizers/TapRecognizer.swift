import Foundation
import CoreGraphics

/// Multi-finger tap and Magic Mouse surface-zone taps.
final class TapRecognizer: @unchecked Sendable {
    private struct Contact {
        var start: Date
        var startPos: CGPoint
        var lastPos: CGPoint
        var maxMajor: Float
    }

    private var contacts: [Int: Contact] = [:]
    private var sessionStart: Date?
    private let lock = NSLock()

    private var lastTapTime: Date?
    private var dragActive = false
    private var hadContacts = false

    private var trackpadContacts: [Int: Contact] = [:]
    private var trackpadSessionStart: Date?

    private var processCount = 0

    struct TapOutcome {
        enum Kind: String {
            case leftClick
            case rightClick
            case middleClick
            case threeFingerMiddle
            case beginDrag
            case endDrag
        }
        var kind: Kind
    }

    func processMagicMouse(
        frame: TouchFrame,
        split: Double,
        deadZone: Double,
        enableLeft: Bool,
        enableRight: Bool,
        enableMiddle: Bool,
        enableDrag: Bool,
        palm: PalmRejector
    ) -> TapOutcome? {
        lock.lock()
        defer { lock.unlock() }

        processCount += 1
        let n = processCount
        let now = frame.timestamp
        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }

        if n <= 30 || live.isEmpty || !live.isEmpty {
            Log.debug(
                .tap,
                "#\(n) processMagicMouse dev=\(frame.deviceID) kind=\(frame.deviceKind.rawValue) " +
                "touches=\(frame.touches.count) live=\(live.count) contacts=\(contacts.count) " +
                "had=\(hadContacts) drag=\(dragActive)"
            )
            for t in frame.touches {
                Log.trace(
                    .tap,
                    "  touch id=\(t.id) phase=\(String(describing: t.phase)) " +
                    "xy=(\(String(format: "%.3f", t.normalized.x)),\(String(format: "%.3f", t.normalized.y))) st=\(t.state)"
                )
            }
        }

        if live.isEmpty {
            let outcome = finishIfNeeded(
                now: now,
                split: split,
                deadZone: deadZone,
                enableLeft: enableLeft,
                enableRight: enableRight,
                enableMiddle: enableMiddle,
                tag: "empty-frame"
            )
            if outcome == nil, hadContacts || !contacts.isEmpty {
                Log.debug(.tap, "#\(n) empty frame but no outcome (contacts cleared or filtered)")
            }
            return outcome
        }

        if !palm.accepts(live) {
            Log.warn(.tap, "#\(n) palm reject live=\(live.count) major=\(live.first.map { String(format: "%.2f", $0.majorAxis) } ?? "-")")
            return nil
        }

        for t in live {
            if var existing = contacts[t.id] {
                existing.lastPos = t.normalized
                existing.maxMajor = max(existing.maxMajor, t.majorAxis)
                contacts[t.id] = existing
            } else {
                contacts[t.id] = Contact(
                    start: now,
                    startPos: t.normalized,
                    lastPos: t.normalized,
                    maxMajor: t.majorAxis
                )
                if sessionStart == nil { sessionStart = now }
                hadContacts = true
                Log.debug(.tap, "#\(n) NEW contact id=\(t.id) at (\(String(format: "%.3f", t.normalized.x)),\(String(format: "%.3f", t.normalized.y)))")
            }
        }

        let liveIDs = Set(live.map(\.id))
        let removed = contacts.keys.filter { !liveIDs.contains($0) }
        if !removed.isEmpty {
            Log.debug(.tap, "#\(n) removed contact ids=\(removed)")
        }
        contacts = contacts.filter { liveIDs.contains($0.key) }

        if contacts.isEmpty, hadContacts {
            return finishIfNeeded(
                now: now,
                split: split,
                deadZone: deadZone,
                enableLeft: enableLeft,
                enableRight: enableRight,
                enableMiddle: enableMiddle,
                tag: "contacts-cleared"
            )
        }

        if enableDrag, live.count == 1, let start = sessionStart, now.timeIntervalSince(start) > 0.20 {
            if let last = lastTapTime, now.timeIntervalSince(last) < 0.5, !dragActive {
                dragActive = true
                contacts.removeAll()
                sessionStart = nil
                hadContacts = false
                Log.info(.tap, "BEGIN DRAG")
                return TapOutcome(kind: .beginDrag)
            }
        }

        return nil
    }

    private func finishIfNeeded(
        now: Date,
        split: Double,
        deadZone: Double,
        enableLeft: Bool,
        enableRight: Bool,
        enableMiddle: Bool,
        tag: String
    ) -> TapOutcome? {
        if dragActive {
            dragActive = false
            contacts.removeAll()
            sessionStart = nil
            hadContacts = false
            Log.info(.tap, "END DRAG (\(tag))")
            return TapOutcome(kind: .endDrag)
        }

        guard hadContacts || !contacts.isEmpty else {
            return nil
        }

        let snapshot = contacts
        let count = max(snapshot.count, 1)
        let duration = now.timeIntervalSince(sessionStart ?? now)
        let moved = snapshot.values.contains {
            hypot($0.lastPos.x - $0.startPos.x, $0.lastPos.y - $0.startPos.y) > 0.06
        }
        let avgX: CGFloat = snapshot.isEmpty
            ? 0.5
            : snapshot.values.map(\.startPos.x).reduce(0, +) / CGFloat(snapshot.count)

        Log.info(
            .tap,
            "FINISH (\(tag)) count=\(count) duration=\(String(format: "%.3f", duration))s " +
            "moved=\(moved) avgX=\(String(format: "%.3f", avgX)) " +
            "split=\(split) dead=\(deadZone) L=\(enableLeft) R=\(enableRight) M=\(enableMiddle)"
        )

        contacts.removeAll()
        sessionStart = nil
        hadContacts = false

        guard duration < 0.45, !moved else {
            Log.warn(.tap, "  ↳ REJECT duration/moved")
            return nil
        }

        if count >= 2, enableMiddle {
            Log.info(.tap, "  ↳ MIDDLE (fingers=\(count))")
            lastTapTime = now
            return TapOutcome(kind: .middleClick)
        }

        guard count == 1 else {
            Log.warn(.tap, "  ↳ REJECT count=\(count)")
            return nil
        }

        lastTapTime = now
        let leftMax = split - deadZone / 2
        let rightMin = split + deadZone / 2

        if Double(avgX) <= leftMax, enableLeft {
            Log.info(.tap, "  ↳ LEFT (x=\(avgX) <= \(leftMax))")
            return TapOutcome(kind: .leftClick)
        }
        if Double(avgX) >= rightMin, enableRight {
            Log.info(.tap, "  ↳ RIGHT (x=\(avgX) >= \(rightMin))")
            return TapOutcome(kind: .rightClick)
        }
        if enableLeft {
            Log.info(.tap, "  ↳ LEFT fallback dead-zone x=\(avgX)")
            return TapOutcome(kind: .leftClick)
        }
        Log.warn(.tap, "  ↳ REJECT no action enabled for x=\(avgX)")
        return nil
    }

    func processTrackpadThreeFingerTap(frame: TouchFrame) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let live = frame.touches.filter { $0.phase != .ended && $0.phase != .cancelled }
        if live.count >= 3 {
            if trackpadSessionStart == nil { trackpadSessionStart = frame.timestamp }
            for t in live {
                if trackpadContacts[t.id] == nil {
                    trackpadContacts[t.id] = Contact(
                        start: frame.timestamp,
                        startPos: t.normalized,
                        lastPos: t.normalized,
                        maxMajor: t.majorAxis
                    )
                }
            }
            return false
        }
        if live.isEmpty, trackpadContacts.count >= 3 {
            let duration = frame.timestamp.timeIntervalSince(trackpadSessionStart ?? frame.timestamp)
            let moved = trackpadContacts.values.contains {
                hypot($0.lastPos.x - $0.startPos.x, $0.lastPos.y - $0.startPos.y) > 0.05
            }
            trackpadContacts.removeAll()
            trackpadSessionStart = nil
            let ok = duration < 0.35 && !moved
            if ok { Log.info(.tap, "trackpad 3-finger middle") }
            return ok
        }
        if live.isEmpty {
            trackpadContacts.removeAll()
            trackpadSessionStart = nil
        }
        return false
    }
}
