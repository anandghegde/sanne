import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// ⌃⌥ window snap via a CGEvent tap so the chord can be consumed (Terminal does not also see it).
/// Input Monitoring is requested only while keyboard snap is enabled.
final class KeyboardSnapMonitor: @unchecked Sendable {
    static let shared = KeyboardSnapMonitor()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let lock = NSLock()
    private var configProvider: () -> SanneConfig = { .default }
    private var isPaused: () -> Bool = { false }
    private var snapshot = SanneConfig()
    private var snapshotPaused = false

    private init() {}

    func start(config: @escaping () -> SanneConfig, paused: @escaping () -> Bool) {
        stop()
        configProvider = config
        isPaused = paused
        refreshSnapshot()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged),
            name: .sanneConfigDidChange,
            object: nil
        )
        installTapIfNeeded()
        Log.info(.app, "KeyboardSnapMonitor started (⌃⌥ arrows)")
    }

    func stop() {
        NotificationCenter.default.removeObserver(self, name: .sanneConfigDidChange, object: nil)
        removeTap()
    }

    @objc private func configChanged() {
        refreshSnapshot()
        installTapIfNeeded()
    }

    private func refreshSnapshot() {
        let cfg = configProvider()
        let paused = isPaused()
        lock.lock()
        snapshot = cfg
        snapshotPaused = paused
        lock.unlock()
    }

    private func installTapIfNeeded() {
        lock.lock()
        let enabled = snapshot.keyboard.enabled
        lock.unlock()

        if !enabled {
            removeTap()
            return
        }
        if tap != nil { return }
        Permissions.requestInputMonitoring()

        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<KeyboardSnapMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                if monitor.handle(event) {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.warn(.app, "KeyboardSnapMonitor: CGEvent tap failed — grant Input Monitoring")
            return
        }
        tap = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        Log.info(.app, "KeyboardSnapMonitor event tap armed")
    }

    private func removeTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
    }

    /// Returns true when the chord was consumed.
    @discardableResult
    private func handle(_ event: CGEvent) -> Bool {
        lock.lock()
        let paused = snapshotPaused
        let cfg = snapshot
        lock.unlock()

        if paused { return false }
        guard cfg.keyboard.enabled else { return false }

        let flags = event.flags
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)
        let hasCommand = flags.contains(.maskCommand)
        guard hasControl, hasOption, !hasShift else { return false }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let slotId: String?
        if hasCommand {
            switch keyCode {
            case kVK_LeftArrow: slotId = GestureSlots.ID.kbDisplayLeft
            case kVK_RightArrow: slotId = GestureSlots.ID.kbDisplayRight
            default: slotId = nil
            }
        } else {
            switch keyCode {
            case kVK_LeftArrow: slotId = GestureSlots.ID.kbLeft
            case kVK_RightArrow: slotId = GestureSlots.ID.kbRight
            case kVK_UpArrow: slotId = GestureSlots.ID.kbUp
            case kVK_DownArrow: slotId = GestureSlots.ID.kbDown
            case kVK_Return, kVK_ANSI_KeypadEnter: slotId = GestureSlots.ID.kbReturn
            default: slotId = nil
            }
        }
        guard let slotId else { return false }

        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let resolved = BindingResolver.resolve(
            slotId: slotId,
            config: cfg,
            frontmostBundleId: front
        ), resolved.enabled else {
            return false
        }

        let gap = CGFloat(cfg.window.gap)
        DispatchQueue.main.async {
            GestureActivity.announce(slotId: slotId)
            let ctx = ActionContext(window: nil, dockApp: nil, gap: gap, haptics: cfg.window.haptics)
            // Repeat ←/→ still cycle thirds when the slot is still the default snap.
            let ok: Bool
            if cfg.keyboard.cycleThirds, resolved.actionId == ActionCatalog.ID.snapLeftHalf {
                ok = WindowManager.shared.cycleLeftFocused(gap: gap, enableThirds: true)
                if ok, cfg.hud.enabled {
                    HUDController.shared.show(title: ActionCatalog.title(for: resolved.actionId))
                }
            } else if cfg.keyboard.cycleThirds, resolved.actionId == ActionCatalog.ID.snapRightHalf {
                ok = WindowManager.shared.cycleRightFocused(gap: gap, enableThirds: true)
                if ok, cfg.hud.enabled {
                    HUDController.shared.show(title: ActionCatalog.title(for: resolved.actionId))
                }
            } else {
                let result = ActionRunner.execute(resolved.actionId, context: ctx)
                if cfg.hud.enabled {
                    if result.ok, ActionCatalog.announcesInHUD(resolved.actionId), let title = result.hudTitle {
                        HUDController.shared.show(title: title)
                    } else if !result.ok, let err = result.errorTitle {
                        HUDController.shared.show(title: err)
                    }
                }
                _ = result.ok
            }
        }
        return true
    }
}
