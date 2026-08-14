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
    @Published var connectedPointers: [IOKitHints.Pointer] = []

    var hasMagicMouse: Bool { connectedPointers.contains(where: \.isMouse) }
    var hasTrackpad: Bool { connectedPointers.contains(where: \.isTrackpad) }

    var connectedDeviceLine: String {
        if connectedPointers.isEmpty {
            return "No Apple trackpad or Magic Mouse connected."
        }
        let names = connectedPointers.map(\.product).joined(separator: " · ")
        if hasMagicMouse { return names }
        return "\(names) · No Magic Mouse connected."
    }

    private var sleepObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var wakeTask: Task<Void, Never>?

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

        if WelcomePrefs.shouldShowOnboarding(hasCompletedWelcome: WelcomePrefs.hasCompletedWelcome) {
            showOnboarding = true
            if !accessibilityTrusted {
                Log.warn(.ax, "Accessibility NOT granted — open Settings and enable Sanne")
            } else {
                Log.info(.app, "First run — showing welcome (Accessibility already granted)")
            }
        }

        wireGestures()
        wireKeyboard()
        wireModifierDrag()
        if configStore.config.paused {
            configStore.update { $0.paused = false }
        }

        refreshDevices()
        startMultitouch()
        observeSleepWake()
        observeDisplayChanges()
        observeConfig()
        LaunchAtLogin.apply(desired: configStore.config.launchAtLogin)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
                self?.refreshConflicts()
                self?.refreshDevices()
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
        wakeTask?.cancel()
        wakeTask = nil
        for o in sleepObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(o)
        }
        sleepObservers.removeAll()
        for o in appObservers {
            NotificationCenter.default.removeObserver(o)
        }
        appObservers.removeAll()
        pollTimer?.invalidate()
    }

    func refreshPermissions() {
        let trusted = Permissions.isAccessibilityTrusted
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
            if trusted {
                // Keep the welcome window open so Start Tutorial is reachable.
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

    func refreshDevices() {
        let next = IOKitHints.applePointers()
        if next != connectedPointers {
            connectedPointers = next
            let names = next.map(\.product).joined(separator: ", ")
            Log.info(.touch, "devices: \(names.isEmpty ? "none" : names)")
        }
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
            applyTrackpadBindResult(count: n, context: "start")
        case .failure(let err):
            applyTrackpadBindFailure(err.localizedDescription, context: "start")
        }
        Log.info(.app, "stats: \(TouchDeviceManager.shared.stats)")
    }

    private func applyTrackpadBindResult(count: Int, context: String) {
        refreshDevices()
        if count > 0 {
            multitouchRunning = true
            multitouchError = nil
            Log.info(.app, "Trackpad multitouch OK devices=\(count) (\(context))")
        } else if hasTrackpad {
            multitouchRunning = false
            multitouchError = "Trackpad present but not bound"
            Log.warn(.app, "Trackpad visible via IOKit but MultitouchSupport bound 0 devices (\(context))")
        } else {
            // Mouse-only Mac: not a trackpad success.
            multitouchRunning = false
            multitouchError = nil
            Log.info(.app, "No trackpad devices (\(context)); Magic Mouse taps may still work")
        }
    }

    private func applyTrackpadBindFailure(_ message: String, context: String) {
        refreshDevices()
        multitouchRunning = false
        multitouchError = message
        Log.warn(.app, "Trackpad path failed (\(context)): \(message)")
    }

    private func observeSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        let stopForSleep: (String) -> Void = { reason in
            TouchDeviceManager.shared.stop()
            MagicMouseTapController.shared.stop()
            Log.info(.touch, "Stopped multitouch (trackpad + Magic Mouse) for \(reason)")
        }
        sleepObservers.append(
            nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                stopForSleep("sleep")
            }
        )
        sleepObservers.append(
            nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
                stopForSleep("screens sleep")
            }
        )
        sleepObservers.append(
            nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in AppController.shared.rebindAfterWake(reason: "wake") }
            }
        )
        sleepObservers.append(
            nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in AppController.shared.rebindAfterWake(reason: "screens wake") }
            }
        )
    }

    private func observeDisplayChanges() {
        appObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    Log.info(.window, "Display configuration changed — screens re-resolved live")
                    AppController.shared.refreshDevices()
                }
            }
        )
    }

    private func rebindAfterWake(reason: String) {
        wakeTask?.cancel()
        wakeTask = Task { @MainActor in
            var lastError: String?
            for (i, delay) in WakeRebind.attemptDelaysNanoseconds.enumerated() {
                try? await Task.sleep(nanoseconds: delay)
                if Task.isCancelled { return }
                let result = await Task.detached {
                    TouchDeviceManager.shared.restart()
                }.value
                await Task.detached {
                    MagicMouseTapController.shared.restart()
                }.value
                switch result {
                case .success(let n):
                    applyTrackpadBindResult(count: n, context: "\(reason) attempt \(i + 1)")
                    let mouseCount = MagicMouseTapController.shared.monitoredDeviceCount
                    if n > 0 || mouseCount > 0 || (!hasTrackpad && !hasMagicMouse) {
                        Log.info(.touch, "Rebound after \(reason) attempt \(i + 1): \(TouchDeviceManager.shared.stats)")
                        refreshPermissions()
                        return
                    }
                    lastError = "No multitouch devices yet"
                case .failure(let err):
                    lastError = err.localizedDescription
                    applyTrackpadBindFailure(err.localizedDescription, context: "\(reason) attempt \(i + 1)")
                }
            }
            if let lastError {
                applyTrackpadBindFailure(lastError, context: "\(reason) exhausted")
            }
            refreshPermissions()
        }
    }

    private func observeConfig() {
        NotificationCenter.default.addObserver(
            forName: .sanneConfigDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                LaunchAtLogin.apply(desired: ConfigStore.shared.config.launchAtLogin)
            }
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
