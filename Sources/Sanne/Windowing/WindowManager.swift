import AppKit
import ApplicationServices

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    let restore = RestoreStore()
    /// Last applied snap layout per window — second same layout restores pre-snap frame.
    private var lastLayout: [WindowIdentity: WindowLayout] = [:]

    func snapWindowUnderCursor(layout: WindowLayout, gap: CGFloat, showPreviewOnly: Bool = false) -> Bool {
        guard Permissions.isAccessibilityTrusted else { return false }
        let appKitPoint = NSEvent.mouseLocation
        guard let window = windowAt(appKitPoint: appKitPoint) else {
            Log.error(.window, "No window under cursor")
            return false
        }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: showPreviewOnly).ok
    }

    /// Snap a window captured at gesture start (preferred over cursor-at-commit).
    func snap(window: AXUIElement, layout: WindowLayout, gap: CGFloat) -> Bool {
        snapDetailed(window: window, layout: layout, gap: gap).ok
    }

    func snapDetailed(window: AXUIElement, layout: WindowLayout, gap: CGFloat) -> (ok: Bool, restored: Bool) {
        snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: true)
    }

    func snapWindowUnderCursorDetailed(layout: WindowLayout, gap: CGFloat) -> (ok: Bool, restored: Bool) {
        guard Permissions.isAccessibilityTrusted else { return (false, false) }
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else {
            Log.error(.window, "No window under cursor")
            return (false, false)
        }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: true)
    }

    func snapFocused(layout: WindowLayout, gap: CGFloat) -> Bool {
        guard let window = focusedWindow() else { return false }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false).ok
    }

    /// Cycle left-side layouts on the focused window (half → third → two-thirds).
    func cycleLeftFocused(gap: CGFloat, enableThirds: Bool) -> Bool {
        guard let window = focusedWindow() else { return false }
        let layout: WindowLayout
        if enableThirds {
            layout = LayoutGeometry.nextLeftLayout(after: lastAppliedLayout(for: window))
        } else {
            layout = .leftHalf
        }
        // Bypass restore-on-same so cycle advances instead of undoing.
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: !enableThirds).ok
    }

    /// Cycle right-side layouts on the focused window.
    func cycleRightFocused(gap: CGFloat, enableThirds: Bool) -> Bool {
        guard let window = focusedWindow() else { return false }
        let layout: WindowLayout
        if enableThirds {
            layout = LayoutGeometry.nextRightLayout(after: lastAppliedLayout(for: window))
        } else {
            layout = .rightHalf
        }
        return snap(window: window, layout: layout, gap: gap, showPreviewOnly: false, allowRestoreOnRepeat: !enableThirds).ok
    }

    /// Move focused window to the adjacent display (left = −1, right = +1), preserving relative size/position.
    @discardableResult
    func moveFocusedToAdjacentDisplay(direction: Int, gap: CGFloat) -> Bool {
        guard let window = focusedWindow() else { return false }
        return moveToAdjacentDisplay(window: window, direction: direction, gap: gap)
    }

    @discardableResult
    func moveToAdjacentDisplay(window: AXUIElement, direction: Int, gap: CGFloat) -> Bool {
        guard Permissions.isAccessibilityTrusted else { return false }
        guard let current = frame(of: window) else {
            Log.error(.window, "move display: no frame")
            return false
        }
        guard let fromScreen = LayoutGeometry.screenContainingAXFrame(current) else {
            Log.error(.window, "move display: no source screen")
            return false
        }
        guard let toScreen = LayoutGeometry.adjacentScreen(from: fromScreen, direction: direction) else {
            Log.info(.window, "move display: no neighbor dir=\(direction)")
            return false
        }

        let fromVis = fromScreen.visibleFrame
        let toVis = toScreen.visibleFrame
        // Relative position within source visible frame (AppKit space for visibleFrame).
        let currentAppKit = LayoutGeometry.axToAppKit(current)

        let relX = fromVis.width > 0 ? (currentAppKit.minX - fromVis.minX) / fromVis.width : 0
        let relY = fromVis.height > 0 ? (currentAppKit.minY - fromVis.minY) / fromVis.height : 0
        let relW = fromVis.width > 0 ? currentAppKit.width / fromVis.width : 1
        let relH = fromVis.height > 0 ? currentAppKit.height / fromVis.height : 1

        let newW = min(max(relW * toVis.width, 200), toVis.width - gap * 2)
        let newH = min(max(relH * toVis.height, 120), toVis.height - gap * 2)
        // Clamp into destination visible frame.
        let newX = min(max(toVis.minX + relX * toVis.width, toVis.minX + gap), toVis.maxX - newW - gap)
        let newY = min(max(toVis.minY + relY * toVis.height, toVis.minY + gap), toVis.maxY - newH - gap)

        let targetAppKit = CGRect(x: newX, y: newY, width: newW, height: newH)
        let targetAX = LayoutGeometry.appKitToAX(targetAppKit)

        guard let id = WindowIdentityResolver.identity(of: window) else {
            Log.error(.window, "move display: no window identity")
            return false
        }
        restore.remember(id, frame: current)
        lastLayout[id] = nil

        let ok = setFrame(window, targetAX)
        Log.info(
            .window,
            "move display dir=\(direction) pid=\(id.pid) win=\(id.windowNumber) " +
            "→ (\(Int(targetAX.minX)),\(Int(targetAX.minY)) \(Int(targetAX.width))×\(Int(targetAX.height))) ok=\(ok)"
        )
        return ok
    }

    func focusedWindow() -> AXUIElement? {
        guard Permissions.isAccessibilityTrusted else { return nil }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref else { return nil }
        return (ref as! AXUIElement)
    }

    func lastAppliedLayout(for window: AXUIElement) -> WindowLayout? {
        guard let id = WindowIdentityResolver.identity(of: window) else { return nil }
        return lastLayout[id]
    }

    func restoreFrame(of window: AXUIElement) -> Bool {
        guard let id = WindowIdentityResolver.identity(of: window),
              let prev = restore.restore(id)
        else { return false }
        lastLayout[id] = nil
        let ok = setFrame(window, prev)
        Log.info(.window, "restore action pid=\(id.pid) win=\(id.windowNumber) ok=\(ok)")
        return ok
    }

    func restoreFocused() -> Bool {
        guard let window = focusedWindow() else { return false }
        return restoreFrame(of: window)
    }

    func storedRestoreFrame(of window: AXUIElement) -> CGRect? {
        guard let id = WindowIdentityResolver.identity(of: window) else { return nil }
        return restore.peek(id)
    }

    func minimize(_ window: AXUIElement) -> Bool {
        let ok = pressButton(window, kAXMinimizeButtonAttribute as String)
        Log.info(.window, "minimize \(ok ? "ok" : "fail")")
        return ok
    }

    func close(_ window: AXUIElement) -> Bool {
        let ok = pressButton(window, kAXCloseButtonAttribute as String)
        Log.info(.window, "close \(ok ? "ok" : "fail")")
        return ok
    }

    func fullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success {
            let current = (value as? Bool) ?? false
            let err = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, (!current) as CFBoolean)
            let ok = err == .success
            Log.info(.window, "fullscreen toggle→\(!current) \(ok ? "ok" : "fail")")
            return ok
        }
        let ok = pressButton(window, kAXZoomButtonAttribute as String)
        Log.info(.window, "fullscreen via zoom \(ok ? "ok" : "fail")")
        return ok
    }

    func minimizeUnderCursor() -> Bool {
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else { return false }
        return minimize(window)
    }

    func closeUnderCursor() -> Bool {
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else { return false }
        return close(window)
    }

    func fullscreenUnderCursor() -> Bool {
        guard let window = windowAt(appKitPoint: NSEvent.mouseLocation) else { return false }
        return fullscreen(window)
    }

    func commitPreview(layout: WindowLayout, gap: CGFloat) {
        SnapPreviewController.shared.hide()
        _ = snapWindowUnderCursor(layout: layout, gap: gap, showPreviewOnly: false)
    }

    func hidePreview() {
        SnapPreviewController.shared.hide()
    }

    func showPreview(layout: WindowLayout, gap: CGFloat, for window: AXUIElement? = nil) {
        let point: CGPoint
        if let window, let f = frame(of: window) {
            point = LayoutGeometry.axPointToAppKit(CGPoint(x: f.midX, y: f.midY))
        } else {
            point = NSEvent.mouseLocation
        }
        guard let screen = LayoutGeometry.screenForAppKitPoint(point) else { return }

        // Second same-layout swipe should preview the restore frame, not another left-half ghost.
        if let window,
           let id = WindowIdentityResolver.identity(of: window),
           lastLayout[id] == layout,
           let prev = restore.peek(id)
        {
            SnapPreviewController.shared.show(axFrame: prev)
            return
        }

        let target = LayoutGeometry.targetFrame(layout: layout, visibleFrameAppKit: screen.visibleFrame, gap: gap)
        SnapPreviewController.shared.show(axFrame: target)
    }

    // MARK: - Internals

    private func snap(
        window: AXUIElement,
        layout: WindowLayout,
        gap: CGFloat,
        showPreviewOnly: Bool,
        allowRestoreOnRepeat: Bool = true
    ) -> (ok: Bool, restored: Bool) {
        guard let current = frame(of: window) else {
            Log.error(.window, "snap: no frame")
            return (false, false)
        }
        guard let id = WindowIdentityResolver.identity(of: window) else {
            Log.error(.window, "snap: no window identity")
            return (false, false)
        }

        // Screen from window center, not live cursor (cursor may have left the titlebar).
        let midAppKit = LayoutGeometry.axPointToAppKit(CGPoint(x: current.midX, y: current.midY))
        guard let screen = LayoutGeometry.screenForAppKitPoint(midAppKit)
                ?? LayoutGeometry.screenForAppKitPoint(NSEvent.mouseLocation)
        else {
            Log.error(.window, "snap: no screen")
            return (false, false)
        }
        let target = LayoutGeometry.targetFrame(layout: layout, visibleFrameAppKit: screen.visibleFrame, gap: gap)

        if showPreviewOnly {
            SnapPreviewController.shared.show(axFrame: target)
            return (true, false)
        }

        // Second application of the same layout → restore original frame (Swish/Rectangle behavior).
        if allowRestoreOnRepeat, lastLayout[id] == layout, let prev = restore.restore(id) {
            lastLayout[id] = nil
            SnapPreviewController.shared.hide()
            let ok = setFrame(window, prev)
            Log.info(.window, "restore layout=\(layout.rawValue) pid=\(id.pid) win=\(id.windowNumber) ok=\(ok)")
            return (ok, true)
        }

        // Remember original only when starting a new snap sequence (not mid-cycle).
        if lastLayout[id] == nil {
            restore.remember(id, frame: current)
        }
        lastLayout[id] = layout

        SnapPreviewController.shared.hide()
        let ok = setFrame(window, target)
        Log.info(
            .window,
            "snap \(layout.rawValue) pid=\(id.pid) win=\(id.windowNumber) " +
            "→ (\(Int(target.minX)),\(Int(target.minY)) \(Int(target.width))×\(Int(target.height))) ok=\(ok)"
        )
        return (ok, false)
    }

    func windowAt(appKitPoint: CGPoint) -> AXUIElement? {
        let ax = LayoutGeometry.appKitPointToAX(appKitPoint)
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(ax.x),
            Float(ax.y),
            &element
        )
        guard err == .success, let element else { return nil }
        return AXQuery.window(from: element)
    }

    func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        if CFGetTypeID(posVal) == AXValueGetTypeID() {
            AXValueGetValue(posVal as! AXValue, .cgPoint, &position)
        }
        if CFGetTypeID(sizeVal) == AXValueGetTypeID() {
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: position, size: size)
    }

    private var lastLiveFrame: [ObjectIdentifier: CGRect] = [:]

    @discardableResult
    func setFrame(_ window: AXUIElement, _ rect: CGRect, mode: AXFrameWriteMode = .commit) -> Bool {
        switch mode {
        case .live:
            return setFrameLive(window, rect)
        case .commit:
            lastLiveFrame[ObjectIdentifier(window)] = rect
            return writeFrame(window, rect, doubleWrite: true)
        }
    }

    @discardableResult
    func setFrameLive(_ window: AXUIElement, _ rect: CGRect) -> Bool {
        let key = ObjectIdentifier(window)
        if AXFrameWrite.shouldSkipLive(previous: lastLiveFrame[key], next: rect) {
            return true
        }
        let kind = AXFrameWrite.liveKind(previous: lastLiveFrame[key], next: rect)
        lastLiveFrame[key] = rect
        switch kind {
        case .move:
            return writePosition(window, rect.origin)
        case .resize:
            return writeFrame(window, rect, doubleWrite: false)
        }
    }

    private func writePosition(_ window: AXUIElement, _ origin: CGPoint) -> Bool {
        PerfCounters.incAXSetFrame()
        var position = origin
        guard let pos = AXValueCreate(.cgPoint, &position) else { return false }
        let err = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        if err != .success {
            Log.warn(.window, "setFrame live pos failed \(err.rawValue)")
        }
        return err == .success
    }

    @discardableResult
    private func writeFrame(_ window: AXUIElement, _ rect: CGRect, doubleWrite: Bool) -> Bool {
        PerfCounters.incAXSetFrame()
        var position = rect.origin
        var size = rect.size
        guard let pos = AXValueCreate(.cgPoint, &position),
              let sz = AXValueCreate(.cgSize, &size) else { return false }
        let sizeErr1 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        let posErr1 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        if doubleWrite {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        }
        let ok = sizeErr1 == .success && posErr1 == .success
        if !ok {
            Log.warn(
                .window,
                "setFrame failed size=\(sizeErr1.rawValue) pos=\(posErr1.rawValue)"
            )
        }
        return ok
    }

    private func pressButton(_ window: AXUIElement, _ attr: String) -> Bool {
        var btn: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attr as CFString, &btn) == .success,
              let btn else { return false }
        let button = btn as! AXUIElement
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }
}
