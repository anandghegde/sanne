import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var prefsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cheatSheetWindow: NSWindow?
    private var tutorialWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshIcon()
        observeState()
    }

    /// Rebuilds the icon only. Menu items are rebuilt in `menuNeedsUpdate` so an
    /// open menu is never replaced out from under the user.
    func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let app = AppController.shared
        button.image = statusImage(trusted: app.accessibilityTrusted, paused: app.isPaused)
        button.appearsDisabled = app.isPaused && app.accessibilityTrusted
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populate(menu, showDebug: NSEvent.modifierFlags.contains(.option))
    }

    private func observeState() {
        let schedule = { [weak self] in
            DispatchQueue.main.async { self?.refreshIcon() }
        }
        AppController.shared.objectWillChange
            .sink { _ in schedule() }
            .store(in: &cancellables)
        ConfigStore.shared.objectWillChange
            .sink { _ in schedule() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .sanneConfigDidChange)
            .sink { _ in schedule() }
            .store(in: &cancellables)
    }

    private func populate(_ menu: NSMenu, showDebug: Bool) {
        let app = AppController.shared
        let cfg = ConfigStore.shared.config

        let status = NSMenuItem(
            title: statusTitle(app),
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)

        if !app.conflicts.isEmpty {
            let conflict = NSMenuItem(
                title: "Also running: \(app.conflicts.joined(separator: ", "))",
                action: nil,
                keyEquivalent: ""
            )
            conflict.isEnabled = false
            menu.addItem(conflict)
            if !app.isPaused {
                let pauseConflict = NSMenuItem(
                    title: "Pause Sanne",
                    action: #selector(togglePause),
                    keyEquivalent: ""
                )
                pauseConflict.target = self
                menu.addItem(pauseConflict)
            }
        }

        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: app.isPaused ? "Resume Gestures" : "Pause Gestures",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pause.keyEquivalentModifierMask = [.command, .option]
        pause.target = self
        menu.addItem(pause)

        let prefs = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let mm = NSMenuItem(
            title: "Magic Mouse Taps",
            action: #selector(toggleMagicMouse),
            keyEquivalent: ""
        )
        mm.target = self
        mm.state = cfg.magicMouseTaps.enabled ? .on : .off
        menu.addItem(mm)

        let titlebar = NSMenuItem(
            title: "Titlebar Window Gestures",
            action: #selector(toggleTitlebar),
            keyEquivalent: ""
        )
        titlebar.target = self
        titlebar.state = cfg.titlebarGestures.enabled ? .on : .off
        menu.addItem(titlebar)

        menu.addItem(.separator())

        let cheat = NSMenuItem(
            title: "Gesture Cheat Sheet…",
            action: #selector(openCheatSheet),
            keyEquivalent: "/"
        )
        cheat.keyEquivalentModifierMask = [.command]
        cheat.target = self
        menu.addItem(cheat)

        let tutorial = NSMenuItem(
            title: "Tutorial…",
            action: #selector(openTutorial),
            keyEquivalent: ""
        )
        tutorial.target = self
        menu.addItem(tutorial)

        if !app.accessibilityTrusted {
            menu.addItem(.separator())
            let ax = NSMenuItem(
                title: "Grant Accessibility…",
                action: #selector(grantAccess),
                keyEquivalent: ""
            )
            ax.target = self
            menu.addItem(ax)
        }

        if showDebug {
            menu.addItem(.separator())
            let debugMenu = NSMenu(title: "Debug")
            debugMenu.addItem(item("Debug Log…", #selector(openDebugLog), key: "d", mods: [.command, .option]))
            debugMenu.addItem(item("Reveal Log File", #selector(revealLog)))
            debugMenu.addItem(.separator())
            debugMenu.addItem(item("Log Zone Under Cursor", #selector(logZoneUnderCursor)))
            debugMenu.addItem(item("Log Multitouch Stats", #selector(logMultitouchStats)))
            debugMenu.addItem(.separator())
            debugMenu.addItem(item("Test Snap: Left Half", #selector(testSnapLeft)))
            debugMenu.addItem(item("Test Snap: Right Half", #selector(testSnapRight)))
            debugMenu.addItem(item("Test Snap: Left Third", #selector(testSnapLeftThird)))
            debugMenu.addItem(item("Test Snap: Maximize", #selector(testSnapMaximize)))
            debugMenu.addItem(item("Test Snap: Restore (same layout twice)", #selector(testSnapRestore)))
            debugMenu.addItem(item("Test: Move focused → display right", #selector(testMoveDisplayRight)))
            debugMenu.addItem(.separator())
            debugMenu.addItem(item("Test Dock: Activate under cursor", #selector(testDockActivate)))
            debugMenu.addItem(item("Test Dock: Hide under cursor", #selector(testDockHide)))
            debugMenu.addItem(item("Test Menubar: Next window", #selector(testMenubarNext)))
            debugMenu.addItem(item("Test Menubar: Hide others", #selector(testMenubarHideOthers)))
            let debugRoot = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
            debugRoot.submenu = debugMenu
            menu.addItem(debugRoot)
        }

        menu.addItem(.separator())

        let updates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updates.target = self
        menu.addItem(updates)

        let about = NSMenuItem(title: "About Sanne", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Sanne", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func statusImage(trusted: Bool, paused: Bool) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let base = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "Sanne")?
            .withSymbolConfiguration(config)
            ?? NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "Sanne")
            ?? NSImage()
        if trusted {
            base.isTemplate = true
            return base
        }
        return badgedStatusImage(base: base, paused: paused)
    }

    /// Template hand with a warning-triangle badge. Shape-only so it is not color-only.
    private func badgedStatusImage(base: NSImage, paused: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let handRect = NSRect(x: 0, y: 2, width: 15, height: 15)
            base.draw(in: handRect, from: .zero, operation: .sourceOver, fraction: paused ? 0.55 : 1)
            if let badge = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "Needs Accessibility"
            ) {
                let badgeRect = NSRect(x: 8, y: 0, width: 10, height: 10)
                badge.draw(in: badgeRect, from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Sanne — needs Accessibility"
        return image
    }

    private func item(
        _ title: String,
        _ action: Selector,
        key: String = "",
        mods: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        i.target = self
        return i
    }

    private func statusTitle(_ app: AppController) -> String {
        if ConfigStore.shared.safeMode { return "Safe mode" }
        if !app.accessibilityTrusted { return "Needs Accessibility" }
        if app.isPaused { return "Paused" }
        if app.isEffectivelyPaused {
            let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "app"
            return "Off in \(name)"
        }
        return "Running"
    }

    @objc private func togglePause() {
        AppController.shared.togglePaused()
        refreshIcon()
    }

    @objc private func toggleMagicMouse() {
        ConfigStore.shared.update { $0.magicMouseTaps.enabled.toggle() }
        refreshIcon()
    }

    @objc private func toggleTitlebar() {
        ConfigStore.shared.update { $0.titlebarGestures.enabled.toggle() }
        refreshIcon()
    }

    @objc private func openSettings() {
        showPreferences()
    }

    @objc private func openDebugLog() {
        PreferencesRoute.request(PreferencesRoute.debug)
        showPreferences()
    }

    @objc private func openCheatSheet() {
        showCheatSheet()
    }

    @objc private func openTutorial() {
        showTutorial()
    }

    @objc private func grantAccess() {
        AppController.shared.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    @objc private func revealLog() {
        let url = URL(fileURLWithPath: LogRing.shared.logFilePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func logZoneUnderCursor() {
        let p = NSEvent.mouseLocation
        let zone = ZoneClassifier.zone(at: p)
        let titlebar = ZoneClassifier.isTitlebar(p)
        let win = WindowManager.shared.windowAt(appKitPoint: p)
        let dockApp = ZoneActions.dockApp(at: p)
        var title = "(none)"
        if let win {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &ref) == .success {
                title = (ref as? String) ?? "?"
            }
        }
        Log.info(
            .zone,
            "cursor=(\(Int(p.x)),\(Int(p.y))) zone=\(zone.rawValue) titlebar=\(titlebar) " +
            "window=\(win != nil ? "yes" : "no") title=\(title.prefix(50)) " +
            "dockApp=\(dockApp?.localizedName ?? "nil")"
        )
        let alert = NSAlert()
        alert.messageText = "Zone: \(zone.rawValue)"
        alert.informativeText = """
        Cursor: (\(Int(p.x)), \(Int(p.y)))
        Titlebar hit: \(titlebar ? "yes" : "no")
        Window: \(win != nil ? title : "none")
        Dock app: \(dockApp?.localizedName ?? "none")

        Hover a title bar, Dock icon, or menu bar and run again.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func logMultitouchStats() {
        let stats = TouchDeviceManager.shared.stats
        Log.info(.touch, "stats \(stats)")
        let alert = NSAlert()
        alert.messageText = "Multitouch"
        alert.informativeText = stats
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func testSnapLeft() { runTestSnap(.leftHalf) }
    @objc private func testSnapRight() { runTestSnap(.rightHalf) }
    @objc private func testSnapLeftThird() { runTestSnap(.leftThird) }
    @objc private func testSnapMaximize() { runTestSnap(.maximize) }
    @objc private func testSnapRestore() {
        // Apply left half twice → second should restore.
        runTestSnap(.leftHalf)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.runTestSnap(.leftHalf)
        }
    }

    @objc private func testMoveDisplayRight() {
        let gap = CGFloat(ConfigStore.shared.config.window.gap)
        let ok = WindowManager.shared.moveFocusedToAdjacentDisplay(direction: 1, gap: gap)
        Log.info(.window, "menu test move display right ok=\(ok)")
        if !ok {
            let alert = NSAlert()
            alert.messageText = "Move display failed"
            alert.informativeText = "Need Accessibility, a focused window, and a screen to the right."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func runTestSnap(_ layout: WindowLayout) {
        let gap = CGFloat(ConfigStore.shared.config.window.gap)
        let ok = WindowManager.shared.snapWindowUnderCursor(layout: layout, gap: gap)
        Log.info(.window, "menu test snap \(layout.rawValue) ok=\(ok)")
        if !ok {
            let alert = NSAlert()
            alert.messageText = "Snap failed"
            alert.informativeText = "Put the cursor over a window, grant Accessibility, then try again."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func testDockActivate() {
        // Menu is under cursor when item fires — use a short delay so user can move to Dock first is hard.
        // Instead resolve app at menu open time is wrong; tell user to use gesture, or resolve now.
        if let app = ZoneActions.dockApp() {
            _ = ZoneActions.activateDockApp(app)
        } else {
            let alert = NSAlert()
            alert.messageText = "No Dock app"
            alert.informativeText = "Hover a Dock icon (not this menu), then use a 2-finger swipe up — or reopen menu while over Dock is not possible. Prefer gestures; this tests AX when cursor is already on Dock (rare from menu)."
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    @objc private func testDockHide() {
        if let app = ZoneActions.dockApp() {
            _ = ZoneActions.hideDockApp(app)
        } else {
            Log.warn(.window, "test dock hide — no app under cursor")
        }
    }

    @objc private func testMenubarNext() {
        ZoneActions.focusNextWindow()
    }

    @objc private func testMenubarHideOthers() {
        ZoneActions.hideOtherApps()
    }

    @objc private func showAbout() {
        PreferencesRoute.request(PreferencesRoute.about)
        showPreferences()
    }

    @objc private func checkForUpdates() {
        let current = AppVersion.marketing
        Task { [weak self] in
            var request = URLRequest(url: UpdateChecker.latestReleaseURL)
            request.setValue("Sanne/\(current)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10
            let outcome: UpdateChecker.Outcome
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                    outcome = .failed("No GitHub Release yet.")
                } else if let release = UpdateChecker.parseLatest(from: data) {
                    outcome = UpdateChecker.evaluate(latest: release, current: current)
                } else {
                    outcome = .failed("Couldn't read the latest release.")
                }
            } catch {
                outcome = .failed("Couldn't check for updates.")
            }
            self?.presentUpdate(outcome, current: current)
        }
    }

    private func presentUpdate(_ outcome: UpdateChecker.Outcome, current: String) {
        let alert = NSAlert()
        switch outcome {
        case .upToDate:
            alert.messageText = "Sanne is up to date"
            alert.informativeText = "You’re on \(current)."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .available(let release):
            alert.messageText = "Update available"
            alert.informativeText = "\(UpdateChecker.stripV(release.tag)) is on GitHub. You’re on \(current)."
            alert.addButton(withTitle: "Open Release")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(release.htmlURL)
            }
        case .failed(let reason):
            alert.messageText = "Couldn’t check for updates"
            alert.informativeText = reason
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func quit() {
        AppController.shared.stop()
        NSApp.terminate(nil)
    }

    func showPreferences() {
        if prefsWindow == nil {
            let view = PreferencesView()
                .environmentObject(AppController.shared)
                .environmentObject(ConfigStore.shared)
            let hosting = NSHostingController(rootView: view)
            // Empty: do not adopt SwiftUI ideal/min size. A tall Form/List would otherwise
            // make the hosting view taller than the window and clip the page title.
            // macOS 12 has no sizingOptions (hosting always tracks standard bounds); the
            // explicit content/min size set below still wins there.
            if #available(macOS 13.0, *) {
                hosting.sizingOptions = []
            }
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sanne Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.titlebarAppearsTransparent = false
            window.setContentSize(NSSize(width: 920, height: 640))
            window.minSize = NSSize(width: 760, height: 520)
            window.setFrameAutosaveName("Sanne.Settings")
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            prefsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        prefsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboardingIfNeeded() {
        guard AppController.shared.showOnboarding else { return }
        if onboardingWindow == nil {
            let view = OnboardingView(
                onFinished: { [weak self] startTutorial in
                    self?.hideOnboarding()
                    if startTutorial {
                        self?.showTutorial()
                    }
                }
            )
            .environmentObject(AppController.shared)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Welcome to Sanne"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 520, height: 520))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            onboardingWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideOnboarding() {
        onboardingWindow?.orderOut(nil)
        restoreAccessoryIfIdle()
    }

    func showCheatSheet() {
        if cheatSheetWindow == nil {
            let hosting = NSHostingController(rootView: CheatSheetView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Gesture Cheat Sheet"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 640, height: 500))
            window.minSize = NSSize(width: 520, height: 400)
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            cheatSheetWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        cheatSheetWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showTutorial() {
        if tutorialWindow == nil {
            let view = TutorialView(
                onOpenCheatSheet: { [weak self] in
                    self?.hideTutorial()
                    self?.showCheatSheet()
                },
                onFinished: { [weak self] in
                    self?.hideTutorial()
                }
            )
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sanne Tutorial"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 540, height: 440))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            tutorialWindow = window
        } else {
            // Rebuild content so steps reset each open.
            let view = TutorialView(
                onOpenCheatSheet: { [weak self] in
                    self?.hideTutorial()
                    self?.showCheatSheet()
                },
                onFinished: { [weak self] in
                    self?.hideTutorial()
                }
            )
            tutorialWindow?.contentViewController = NSHostingController(rootView: view)
        }
        NSApp.setActivationPolicy(.regular)
        tutorialWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideTutorial() {
        tutorialWindow?.orderOut(nil)
        restoreAccessoryIfIdle()
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.restoreAccessoryIfIdle()
        }
    }

    private func restoreAccessoryIfIdle() {
        let anyVisible =
            prefsWindow?.isVisible == true
            || onboardingWindow?.isVisible == true
            || cheatSheetWindow?.isVisible == true
            || tutorialWindow?.isVisible == true
        if !anyVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
