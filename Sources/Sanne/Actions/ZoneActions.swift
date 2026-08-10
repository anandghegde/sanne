import AppKit
import ApplicationServices

/// Dock + menubar zone actions (activate, hide, window cycle, etc.).
@MainActor
enum ZoneActions {
    // MARK: - Dock

    /// App represented by the Dock icon under the cursor (AX Dock item title → running app).
    static func dockApp(at appKitPoint: CGPoint = NSEvent.mouseLocation) -> NSRunningApplication? {
        guard Permissions.isAccessibilityTrusted else { return nil }
        let ax = LayoutGeometry.appKitPointToAX(appKitPoint)
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(ax.x),
            Float(ax.y),
            &element
        )
        guard err == .success, let element else { return nil }

        var cursor: AXUIElement? = element
        for _ in 0..<14 {
            guard let c = cursor else { break }
            let role = stringAttr(c, kAXRoleAttribute as String) ?? ""
            // Dock icons: AXDockItem; some macOS versions expose application dock items.
            if role == "AXDockItem" || role.contains("DockItem") {
                let title = stringAttr(c, kAXTitleAttribute as String)
                    ?? stringAttr(c, kAXDescriptionAttribute as String)
                if let title, let app = matchRunningApp(title: title) {
                    return app
                }
            }
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(c, kAXParentAttribute as CFString, &parent) == .success,
               let parent
            {
                cursor = (parent as! AXUIElement)
            } else {
                break
            }
        }

        // Fallback: title of leaf element if Dock zone geometrically.
        if ZoneClassifier.zone(at: appKitPoint) == .dock {
            let title = stringAttr(element, kAXTitleAttribute as String)
                ?? stringAttr(element, kAXDescriptionAttribute as String)
            if let title, let app = matchRunningApp(title: title) {
                return app
            }
        }
        return nil
    }

    @discardableResult
    static func activateDockApp(_ app: NSRunningApplication) -> Bool {
        // Unhide if hidden, then activate.
        if app.isHidden {
            app.unhide()
        }
        let ok = app.activate(options: [.activateIgnoringOtherApps])
        // Unminimize windows of this app when possible.
        unminimizeWindows(of: app)
        Log.info(.window, "dock activate \(app.localizedName ?? "?") ok=\(ok)")
        return ok
    }

    @discardableResult
    static func hideDockApp(_ app: NSRunningApplication) -> Bool {
        // Prefer hide (keeps Dock badge) over minimize-all; matches Swish “hide app”.
        let ok = app.hide()
        Log.info(.window, "dock hide \(app.localizedName ?? "?") ok=\(ok)")
        return ok
    }

    static func newWindowForDockApp(_ app: NSRunningApplication) {
        _ = app.activate(options: [.activateIgnoringOtherApps])
        // Brief delay so the app is frontmost before ⌘N.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            KeyEmitter.commandN()
            Log.info(.window, "dock new window → \(app.localizedName ?? "?")")
        }
    }

    static func quitDockApp(_ app: NSRunningApplication) {
        _ = app.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            KeyEmitter.commandQ()
            Log.info(.window, "dock quit → \(app.localizedName ?? "?")")
        }
    }

    // MARK: - Menubar

    static func focusNextWindow() {
        KeyEmitter.nextWindow()
        Log.info(.window, "menubar → next window")
    }

    static func focusPreviousWindow() {
        KeyEmitter.previousWindow()
        Log.info(.window, "menubar → previous window")
    }

    static func hideOtherApps() {
        KeyEmitter.hideOthers()
        Log.info(.window, "menubar → hide others")
    }

    /// Bring frontmost app’s windows forward / unminimize.
    static func unminimizeFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        if app.isHidden { app.unhide() }
        unminimizeWindows(of: app)
        _ = app.activate(options: [.activateIgnoringOtherApps])
        Log.info(.window, "menubar → unminimize \(app.localizedName ?? "?")")
    }

    // MARK: - Internals

    private static func matchRunningApp(title: String) -> NSRunningApplication? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }
        // Exact localized name
        if let app = running.first(where: { $0.localizedName == t }) {
            return app
        }
        // Case-insensitive
        if let app = running.first(where: {
            ($0.localizedName ?? "").caseInsensitiveCompare(t) == .orderedSame
        }) {
            return app
        }
        // Prefix / contains (Dock may append status text)
        if let app = running.first(where: {
            let name = $0.localizedName ?? ""
            return t.hasPrefix(name) || name.hasPrefix(t) || t.contains(name)
        }) {
            return app
        }
        Log.debug(.zone, "dock title unmatched: \(t)")
        return nil
    }

    private static func unminimizeWindows(of app: NSRunningApplication) {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let list = windowsRef as? [AXUIElement]
        else { return }
        for win in list {
            var minimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minimized) == .success,
               let minimized = minimized as? Bool,
               minimized
            {
                AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, false as CFBoolean)
            }
        }
    }

    private static func stringAttr(_ el: AXUIElement, _ name: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &ref) == .success else { return nil }
        return ref as? String
    }
}
