import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let configStore = ConfigStore.shared
    @Published var accessibilityTrusted = Permissions.isAccessibilityTrusted
    @Published var multitouchRunning = false
    @Published var multitouchError: String?
    @Published var conflicts: [String] = []
    @Published var showOnboarding = false
    @Published var showPreferences = false

    private var sleepObservers: [NSObjectProtocol] = []
    private var pollTimer: Timer?

    private init() {}

    func start() {
        NSApp.setActivationPolicy(.accessory)
        Log.info(.app, "Sanne starting…")
        Log.info(.app, "binary: \(Permissions.processPath)")
        Log.info(.app, "log file: \(LogRing.shared.logFilePath)")
        Log.info(.app, "pid: \(ProcessInfo.processInfo.processIdentifier)")

        refreshPermissions()
        refreshConflicts()
        Log.info(.ax, "Accessibility trusted=\(accessibilityTrusted)")

        if !accessibilityTrusted {
            showOnboarding = true
            Log.warn(.ax, "Accessibility NOT granted — open Settings and enable Sanne")
        }

        wireGestures()
        wireKeyboard()
        wireModifierDrag()
        startMultitouch()
        observeSleepWake()
        observeConfig()
        LaunchAtLogin.apply(desired: configStore.config.launchAtLogin)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
                self?.refreshConflicts()
            }
        }

        Log.info(.app, "Sanne started. Open Settings → Debug Log, then tap Magic Mouse.")
        Log.info(.app, "launchAtLogin config=\(configStore.config.launchAtLogin) sm=\(LaunchAtLogin.status.rawValue) bundled=\(LaunchAtLogin.isBundledApp)")
    }

    func stop() {
        GestureEngine.shared.stop()
        KeyboardSnapMonitor.shared.stop()
        ModifierDragController.shared.stop()
        TouchDeviceManager.shared.stop()
        for o in sleepObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        sleepObservers.removeAll()
        pollTimer?.invalidate()
    }

    func refreshPermissions() {
        let trusted = Permissions.isAccessibilityTrusted
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
            if trusted {
                showOnboarding = false
                startMultitouch()
            }
        }
    }

    func requestAccessibility() {
        Permissions.ensureAccessibility(prompt: true)
        refreshPermissions()
    }

    func refreshConflicts() {
        conflicts = CompetingApps.runningConflicts()
    }

    func togglePaused() {
        configStore.update { $0.paused.toggle() }
    }

    var isPaused: Bool { configStore.config.paused }

    /// Global pause **or** frontmost app has a full (all-scope) override.
    var isEffectivelyPaused: Bool {
        let cfg = configStore.config
        if cfg.paused { return true }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return cfg.isDisabled(forFrontmostBundleId: front)
    }

    private var frontmostBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Pause Magic Mouse taps for global pause or matching per-app scope.
    var isMagicMousePaused: Bool {
        let cfg = configStore.config
        if cfg.paused { return true }
        return cfg.pausesMagicMouse(forFrontmostBundleId: frontmostBundleId)
    }

    /// Pause titlebar / Dock / menubar / free-space trackpad.
    var isWindowGesturesPaused: Bool {
        let cfg = configStore.config
        if cfg.paused { return true }
        return cfg.pausesWindowGestures(forFrontmostBundleId: frontmostBundleId)
    }

    var isKeyboardPaused: Bool {
        let cfg = configStore.config
        if cfg.paused { return true }
        return cfg.pausesKeyboard(forFrontmostBundleId: frontmostBundleId)
    }

    var isModifierDragPaused: Bool {
        let cfg = configStore.config
        if cfg.paused { return true }
        return cfg.pausesModifierDrag(forFrontmostBundleId: frontmostBundleId)
    }

    private func wireGestures() {
        GestureEngine.shared.start(
            config: { ConfigStore.shared.config },
            paused: { AppController.shared.isWindowGesturesPaused },
            magicMousePaused: { AppController.shared.isMagicMousePaused }
        )
    }

    private func wireKeyboard() {
        KeyboardSnapMonitor.shared.start(
            config: { ConfigStore.shared.config },
            paused: { AppController.shared.isKeyboardPaused }
        )
    }

    private func wireModifierDrag() {
        ModifierDragController.shared.start(
            config: { ConfigStore.shared.config },
            paused: { AppController.shared.isModifierDragPaused }
        )
    }

    private func startMultitouch() {
        // Trackpad path (titlebar gestures). Magic Mouse taps start inside GestureEngine.
        switch TouchDeviceManager.shared.start() {
        case .success(let n):
            multitouchRunning = true
            multitouchError = nil
            Log.info(.app, "Trackpad multitouch OK devices=\(n)")
        case .failure(let err):
            // Mouse-only machines may have 0 trackpad devices — still OK if mouse taps work
            multitouchRunning = true
            multitouchError = nil
            Log.warn(.app, "Trackpad path: \(err.localizedDescription) (Magic Mouse taps may still work)")
        }
        Log.info(.app, "stats: \(TouchDeviceManager.shared.stats)")
    }

    private func observeSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        sleepObservers.append(
            nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                TouchDeviceManager.shared.stop()
                MagicMouseTapController.shared.stop()
                Log.info(.touch, "Stopped multitouch (trackpad + Magic Mouse) for sleep")
            }
        )
        sleepObservers.append(
            nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    // Short debounce so the stack settles after wake.
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    let result = await Task.detached {
                        TouchDeviceManager.shared.restart()
                    }.value
                    // Magic Mouse must rebind too (separate device registration).
                    await Task.detached {
                        MagicMouseTapController.shared.restart()
                    }.value
                    switch result {
                    case .success:
                        AppController.shared.multitouchRunning = true
                        AppController.shared.multitouchError = nil
                        Log.info(.touch, "Multitouch rebound after wake: \(TouchDeviceManager.shared.stats)")
                    case .failure(let err):
                        // Trackpad may be absent; Magic Mouse restart still ran.
                        AppController.shared.multitouchRunning = true
                        AppController.shared.multitouchError = nil
                        Log.warn(.touch, "Trackpad rebind: \(err.localizedDescription); Magic Mouse restarted")
                    }
                    AppController.shared.refreshPermissions()
                }
            }
        )
    }

    private func observeConfig() {
        NotificationCenter.default.addObserver(
            forName: .sanneConfigDidChange,
            object: nil,
            queue: .main
        ) { _ in
            // Engine reads config live; launch-at-login is applied from the Settings toggle.
        }
    }

    /// Toggle launch-at-login preference and register/unregister the login item.
    func setLaunchAtLogin(_ enabled: Bool) {
        configStore.update { $0.launchAtLogin = enabled }
        if !LaunchAtLogin.isBundledApp {
            Log.warn(.app, "Launch at login saved to config, but needs Sanne.app (see scripts/package-app.sh)")
            return
        }
        switch LaunchAtLogin.setEnabled(enabled) {
        case .success:
            break
        case .failure:
            // Keep config as user chose; status may be requiresApproval.
            break
        }
    }
}
