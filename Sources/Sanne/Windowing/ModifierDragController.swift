import AppKit
import ApplicationServices

/// Hold modifiers + left-drag to move (⌥⌘) or resize (⌃⌘) a window from anywhere.
@MainActor
final class ModifierDragController {
    static let shared = ModifierDragController()

    private enum Mode {
        case move
        case resize(edges: EdgeSet)
    }

    private struct EdgeSet: OptionSet {
        let rawValue: Int
        static let left = EdgeSet(rawValue: 1 << 0)
        static let right = EdgeSet(rawValue: 1 << 1)
        static let top = EdgeSet(rawValue: 1 << 2)
        static let bottom = EdgeSet(rawValue: 1 << 3)
    }

    private var monitors: [Any] = []
    private var configProvider: () -> SanneConfig = { .default }
    private var isPaused: () -> Bool = { false }

    private var activeWindow: AXUIElement?
    private var mode: Mode?
    private var startMouseAppKit: CGPoint = .zero
    private var startFrameAX: CGRect = .zero
    private var didLogStart = false

    private init() {}

    func start(config: @escaping () -> SanneConfig, paused: @escaping () -> Bool) {
        configProvider = config
        isPaused = paused
        stop()

        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .leftMouseDragged,
            .leftMouseUp,
            .flagsChanged,
        ]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
        Log.info(.window, "ModifierDragController started (⌥⌘ move · ⌃⌘ resize)")
    }

    func stop() {
        endSession()
        for m in monitors {
            NSEvent.removeMonitor(m)
        }
        monitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        if isPaused() {
            endSession()
            return
        }
        let cfg = configProvider().modifierDrag
        guard cfg.enabled else {
            endSession()
            return
        }

        switch event.type {
        case .leftMouseDown:
            beginIfNeeded(event: event, cfg: cfg)
        case .leftMouseDragged:
            if activeWindow == nil {
                beginIfNeeded(event: event, cfg: cfg)
            }
            updateDrag(event: event)
        case .leftMouseUp:
            endSession()
        case .flagsChanged:
            // Drop session if the activating chord is released mid-drag.
            if activeWindow != nil {
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let stillMove = cfg.moveEnabled && Self.matches(mods, cfg.moveModifiers)
                let stillResize = cfg.resizeEnabled && Self.matches(mods, cfg.resizeModifiers)
                if !stillMove && !stillResize {
                    endSession()
                }
            }
        default:
            break
        }
    }

    private func beginIfNeeded(event: NSEvent, cfg: ModifierDragConfig) {
        guard activeWindow == nil else { return }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        let isMove = cfg.moveEnabled && Self.matches(mods, cfg.moveModifiers)
        let isResize = cfg.resizeEnabled && Self.matches(mods, cfg.resizeModifiers)
        // Prefer resize when both chords match (resize is usually more specific).
        guard isMove || isResize else { return }

        guard Permissions.isAccessibilityTrusted else { return }
        let point = NSEvent.mouseLocation
        guard let window = WindowManager.shared.windowAt(appKitPoint: point),
              let frame = WindowManager.shared.frame(of: window)
        else { return }

        // Don't steal interaction from our own UI.
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        if pid == ProcessInfo.processInfo.processIdentifier { return }

        activeWindow = window
        startMouseAppKit = point
        startFrameAX = frame
        didLogStart = false

        if isResize {
            let edges = Self.nearestEdges(cursorAppKit: point, frameAX: frame)
            mode = .resize(edges: edges.isEmpty ? [.right, .bottom] : edges)
        } else {
            mode = .move
        }
    }

    private func updateDrag(event: NSEvent) {
        guard let window = activeWindow, let mode else { return }
        let point = NSEvent.mouseLocation
        let dxApp = point.x - startMouseAppKit.x
        let dyApp = point.y - startMouseAppKit.y // AppKit: up is +

        // AX coordinates: origin top-left of primary, Y increases downward.
        let dX = dxApp
        let dY = -dyApp

        var next = startFrameAX
        switch mode {
        case .move:
            next.origin.x = startFrameAX.origin.x + dX
            next.origin.y = startFrameAX.origin.y + dY
        case .resize(let edges):
            if edges.contains(.left) {
                let newX = startFrameAX.origin.x + dX
                let maxX = startFrameAX.maxX - 120
                next.origin.x = min(newX, maxX)
                next.size.width = startFrameAX.maxX - next.origin.x
            }
            if edges.contains(.right) {
                next.size.width = max(120, startFrameAX.width + dX)
            }
            if edges.contains(.top) {
                // Top edge in AX: decreasing Y enlarges upward in AppKit terms.
                let newY = startFrameAX.origin.y + dY
                let maxY = startFrameAX.maxY - 80
                next.origin.y = min(newY, maxY)
                next.size.height = startFrameAX.maxY - next.origin.y
            }
            if edges.contains(.bottom) {
                next.size.height = max(80, startFrameAX.height + dY)
            }
        }

        if !didLogStart {
            didLogStart = true
            switch mode {
            case .move:
                Log.info(.window, "modifier-drag move begin")
            case .resize(let edges):
                Log.info(.window, "modifier-drag resize begin edges=\(edges.rawValue)")
            }
        }

        _ = WindowManager.shared.setFrame(window, next)
    }

    private func endSession() {
        if activeWindow != nil {
            Log.debug(.window, "modifier-drag end")
        }
        activeWindow = nil
        mode = nil
        didLogStart = false
    }

    // MARK: - Helpers

    private static func matches(_ flags: NSEvent.ModifierFlags, _ required: [ModifierName]) -> Bool {
        guard !required.isEmpty else { return false }
        let need = flagSet(required)
        let relevant: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let present = flags.intersection(relevant)
        return present == need
    }

    private static func flagSet(_ names: [ModifierName]) -> NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        for n in names {
            switch n {
            case .control: f.insert(.control)
            case .option: f.insert(.option)
            case .shift: f.insert(.shift)
            case .command: f.insert(.command)
            }
        }
        return f
    }

    /// Pick resize edges from cursor position inside the window (thirds / near-edge).
    private static func nearestEdges(cursorAppKit: CGPoint, frameAX: CGRect) -> EdgeSet {
        let frameAppKit = LayoutGeometry.axToAppKit(frameAX)
        let relX = frameAppKit.width > 0 ? (cursorAppKit.x - frameAppKit.minX) / frameAppKit.width : 0.5
        let relY = frameAppKit.height > 0 ? (cursorAppKit.y - frameAppKit.minY) / frameAppKit.height : 0.5

        var edges: EdgeSet = []
        if relX < 0.33 { edges.insert(.left) }
        else if relX > 0.67 { edges.insert(.right) }
        if relY < 0.33 { edges.insert(.bottom) }
        else if relY > 0.67 { edges.insert(.top) }

        // Center click → grow from bottom-right (common default).
        if edges.isEmpty {
            edges = [.right, .bottom]
        }
        return edges
    }
}
