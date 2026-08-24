import AppKit
import SwiftUI

/// Process entry point. Lives in the library so the thin `Sanne` executable and any future
/// harness can boot the same way; `@main` sits on the executable target only.
public enum SanneAppEntry {
    @MainActor
    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppController.shared.start()
        menuBar.install()
        menuBar.showOnboardingIfNeeded()

        NotificationCenter.default.addObserver(
            forName: .sanneShowTutorial,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.menuBar.showTutorial() }
        }
        NotificationCenter.default.addObserver(
            forName: .sanneShowCheatSheet,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.menuBar.showCheatSheet() }
        }
        NotificationCenter.default.addObserver(
            forName: .sanneShowPreferences,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.menuBar.showPreferences() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBar.showPreferences()
        return true
    }
}
