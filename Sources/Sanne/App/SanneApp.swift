import AppKit
import SwiftUI

@main
struct SanneAppEntry {
    static func main() {
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
            Task { @MainActor in self?.menuBar.showTutorial() }
        }
        NotificationCenter.default.addObserver(
            forName: .sanneShowCheatSheet,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.menuBar.showCheatSheet() }
        }

        // Keep menu bar icon state in sync
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.menuBar.refreshMenu()
                if !AppController.shared.showOnboarding {
                    self?.menuBar.hideOnboarding()
                }
            }
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
