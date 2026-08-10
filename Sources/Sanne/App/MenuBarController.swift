import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var prefsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cheatSheetWindow: NSWindow?
    private var tutorialWindow: NSWindow?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "hand.draw",
                accessibilityDescription: "Sanne"
            )
            button.image?.isTemplate = true
        }
        item.menu = buildMenu()
        statusItem = item
        refreshMenu()
    }

    func refreshMenu() {
        statusItem?.menu = buildMenu()
        let paused = AppController.shared.isPaused
        statusItem?.button?.appearsDisabled = paused
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let app = AppController.shared

        let status = NSMenuItem(
            title: statusTitle(app),
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)

        if !app.conflicts.isEmpty {
            menu.addItem(NSMenuItem(
                title: "⚠ Conflict: \(app.conflicts.joined(separator: ", "))",
                action: nil,
                keyEquivalent: ""
            ))
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

        menu.addItem(.separator())

        if !app.accessibilityTrusted {
            let ax = NSMenuItem(
                title: "Grant Accessibility…",
                action: #selector(grantAccess),
                keyEquivalent: ""
            )
            ax.target = self
            menu.addItem(ax)
        }

        let debugMenu = NSMenu(title: "Debug")
        debugMenu.addItem(item("Debug Log…", #selector(openSettings), key: "d", mods: [.command, .option]))
        debugMenu.addItem(item("Reveal Log File", #selector(revealLog)))
        debugMenu.addItem(.separator())
        debugMenu.addItem(item("Log Zone Under Cursor", #selector(logZoneUnderCursor)))
        debugMenu.addItem(item("Log Multitouch Stats", #selector(logMultitouchStats)))
        debugMenu.addItem(.separator())
        // AX path tests without needing a trackpad gesture (isolates snap vs recognition).
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

        let about = NSMenuItem(title: "About Sanne", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Sanne", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
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
        if !app.accessibilityTrusted { return "Sanne — needs Accessibility" }
        if app.isPaused { return "Sanne — paused" }
        if app.isEffectivelyPaused {
            let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "app"
            return "Sanne — off for \(name)"
        }
        if app.multitouchError != nil { return "Sanne — multitouch error" }
        if app.multitouchRunning { return "Sanne — running" }
        return "Sanne"
    }

    @objc private func togglePause() {
        AppController.shared.togglePaused()
        refreshMenu()
    }

    @objc private func openSettings() {
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
        let alert = NSAlert()
        alert.messageText = "Sanne"
        alert.informativeText = """
        Free & open source gestures for Magic Mouse and trackpad.

        Version \(AppVersion.display)

        Log: \(LogRing.shared.logFilePath)
        Binary: \(Permissions.processPath)
        Stats: \(TouchDeviceManager.shared.stats)
        """
        alert.alertStyle = .informational
        alert.runModal()
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
            let window = NSWindow(contentViewController: hosting)
            window.title = "Sanne"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.titlebarAppearsTransparent = false
            window.setContentSize(NSSize(width: 820, height: 560))
            window.minSize = NSSize(width: 720, height: 480)
            window.center()
            window.isReleasedWhenClosed = false
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
            window.setContentSize(NSSize(width: 540, height: 400))
            window.center()
            window.isReleasedWhenClosed = false
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
