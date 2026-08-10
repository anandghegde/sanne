import AppKit
import Carbon.HIToolbox

/// Global ⌃⌥ window snap shortcuts (Rectangle-style chord; never bare arrows).
@MainActor
final class KeyboardSnapMonitor {
    static let shared = KeyboardSnapMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var configProvider: () -> SanneConfig = { .default }
    private var isPaused: () -> Bool = { false }

    private init() {}

    func start(config: @escaping () -> SanneConfig, paused: @escaping () -> Bool) {
        configProvider = config
        isPaused = paused
        stop()

        let mask: NSEvent.EventTypeMask = [.keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if self?.handle(event) == true {
                return nil
            }
            return event
        }
        Log.info(.app, "KeyboardSnapMonitor started (⌃⌥ arrows)")
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        if isPaused() { return false }
        let cfg = configProvider()
        guard cfg.keyboard.enabled else { return false }

        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let wantsControlOption =
            mods.contains(.control) &&
            mods.contains(.option) &&
            !mods.contains(.shift)

        guard wantsControlOption else { return false }

        let gap = CGFloat(cfg.window.gap)
        let haptics = cfg.window.haptics
        let withCommand = mods.contains(.command)

        // ⌃⌥⌘ ←/→ → adjacent display
        if withCommand {
            guard cfg.keyboard.moveToAdjacentDisplay else { return false }
            switch Int(event.keyCode) {
            case kVK_LeftArrow:
                let ok = WindowManager.shared.moveFocusedToAdjacentDisplay(direction: -1, gap: gap)
                if ok {
                    Log.info(.window, "keyboard → display left")
                    Haptics.fire(enabled: haptics)
                }
                return ok
            case kVK_RightArrow:
                let ok = WindowManager.shared.moveFocusedToAdjacentDisplay(direction: 1, gap: gap)
                if ok {
                    Log.info(.window, "keyboard → display right")
                    Haptics.fire(enabled: haptics)
                }
                return ok
            default:
                return false
            }
        }

        guard cfg.keyboard.snapWithArrows else { return false }
        // ⌃⌥ only (no ⌘) for snap
        guard !withCommand else { return false }

        let ok: Bool
        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            ok = WindowManager.shared.cycleLeftFocused(gap: gap, enableThirds: cfg.keyboard.cycleThirds)
            if ok { Log.info(.window, "keyboard → cycle left") }
        case kVK_RightArrow:
            ok = WindowManager.shared.cycleRightFocused(gap: gap, enableThirds: cfg.keyboard.cycleThirds)
            if ok { Log.info(.window, "keyboard → cycle right") }
        case kVK_UpArrow:
            ok = WindowManager.shared.snapFocused(layout: .maximize, gap: gap)
            if ok { Log.info(.window, "keyboard → maximize") }
        case kVK_DownArrow:
            ok = WindowManager.shared.snapFocused(layout: .almostMaximize, gap: gap)
            if ok { Log.info(.window, "keyboard → almostMaximize") }
        case kVK_Return, kVK_ANSI_KeypadEnter:
            ok = WindowManager.shared.snapFocused(layout: .centerLarge, gap: gap)
            if ok { Log.info(.window, "keyboard → centerLarge") }
        default:
            return false
        }

        if ok { Haptics.fire(enabled: haptics) }
        return ok
    }
}
