import AppKit
import ApplicationServices

/// Hold modifiers + left-drag to move (⌥⌘) or resize (⌃⌘) a window from anywhere.
@MainActor
final class ModifierDragController {
    static let shared = ModifierDragController()

    private var monitors: [Any] = []
    private var configProvider: () -> SanneConfig = { .default }
    private var isPaused: () -> Bool = { false }
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
            self?.handle(event)
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
        WindowMover.shared.end()
        didLogStart = false
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
            if !WindowMover.shared.isActive {
                beginIfNeeded(event: event, cfg: cfg)
            }
            if WindowMover.shared.isActive {
                if !didLogStart {
                    didLogStart = true
                    Log.info(.window, "modifier-drag \(WindowMover.shared.isActive ? "session" : "") begin")
                }
                WindowMover.shared.update()
            }
        case .leftMouseUp:
            endSession()
        case .flagsChanged:
            if WindowMover.shared.isActive {
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
        guard !WindowMover.shared.isActive else { return }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        let isMove = cfg.moveEnabled && Self.matches(mods, cfg.moveModifiers)
        let isResize = cfg.resizeEnabled && Self.matches(mods, cfg.resizeModifiers)
        guard isMove || isResize else { return }

        let kind: WindowMoverKind = isResize ? .resize : .move
        _ = WindowMover.shared.begin(kind: kind)
        didLogStart = false
    }

    private func endSession() {
        if WindowMover.shared.isActive {
            Log.debug(.window, "modifier-drag end")
        }
        WindowMover.shared.end()
        didLogStart = false
    }

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
}
