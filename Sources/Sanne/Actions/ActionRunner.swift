import AppKit
import ApplicationServices
import CoreGraphics
import Darwin

/// Context captured at gesture begin / recognition time.
struct ActionContext {
    var window: AXUIElement?
    var dockApp: NSRunningApplication?
    var gap: CGFloat
    var haptics: Bool
    /// Multi-click count for click actions (1 = single).
    var clickCount: Int = 1
}

/// Executes catalog action IDs.
@MainActor
enum ActionRunner {
    @discardableResult
    static func run(_ actionId: String, context: ActionContext) -> Bool {
        if actionId == ActionCatalog.ID.none
            || actionId == ActionCatalog.ID.drag
            || actionId == ActionCatalog.ID.moveWindow
        {
            return false
        }

        let ok: Bool
        switch actionId {
        case ActionCatalog.ID.snapLeftHalf: ok = snap(.leftHalf, context)
        case ActionCatalog.ID.snapRightHalf: ok = snap(.rightHalf, context)
        case ActionCatalog.ID.snapTopHalf: ok = snap(.topHalf, context)
        case ActionCatalog.ID.snapBottomHalf: ok = snap(.bottomHalf, context)
        case ActionCatalog.ID.snapTopLeft: ok = snap(.topLeft, context)
        case ActionCatalog.ID.snapTopRight: ok = snap(.topRight, context)
        case ActionCatalog.ID.snapBottomLeft: ok = snap(.bottomLeft, context)
        case ActionCatalog.ID.snapBottomRight: ok = snap(.bottomRight, context)
        case ActionCatalog.ID.snapLeftThird: ok = snap(.leftThird, context)
        case ActionCatalog.ID.snapCenterThird: ok = snap(.centerThird, context)
        case ActionCatalog.ID.snapRightThird: ok = snap(.rightThird, context)
        case ActionCatalog.ID.snapLeftTwoThirds: ok = snap(.leftTwoThirds, context)
        case ActionCatalog.ID.snapRightTwoThirds: ok = snap(.rightTwoThirds, context)
        case ActionCatalog.ID.snapMaximize: ok = snap(.maximize, context)
        case ActionCatalog.ID.snapCenter: ok = snap(.center, context)
        case ActionCatalog.ID.snapCenterLarge: ok = snap(.centerLarge, context)
        case ActionCatalog.ID.snapAlmostMaximize: ok = snap(.almostMaximize, context)

        case ActionCatalog.ID.minimize:
            if let w = context.window {
                ok = WindowManager.shared.minimize(w)
            } else {
                ok = WindowManager.shared.minimizeUnderCursor()
            }

        case ActionCatalog.ID.close:
            if let w = context.window {
                ok = WindowManager.shared.close(w)
            } else {
                ok = WindowManager.shared.closeUnderCursor()
            }

        case ActionCatalog.ID.fullscreen:
            if let w = context.window {
                ok = WindowManager.shared.fullscreen(w)
            } else {
                ok = WindowManager.shared.fullscreenUnderCursor()
            }

        case ActionCatalog.ID.moveDisplayLeft:
            ok = moveDisplay(-1, context)
        case ActionCatalog.ID.moveDisplayRight:
            ok = moveDisplay(1, context)

        case ActionCatalog.ID.clickLeft:
            ClickEmitter.click(.left, clickCount: max(1, context.clickCount))
            ok = true
        case ActionCatalog.ID.clickRight:
            ClickEmitter.click(.right, clickCount: 1)
            ok = true
        case ActionCatalog.ID.clickMiddle:
            ClickEmitter.click(.middle, clickCount: 1)
            ok = true

        case ActionCatalog.ID.missionControl:
            KeyEmitter.missionControl()
            ok = true
        case ActionCatalog.ID.appExpose:
            KeyEmitter.appExpose()
            ok = true
        case ActionCatalog.ID.spaceLeft:
            KeyEmitter.spaceLeft()
            ok = true
        case ActionCatalog.ID.spaceRight:
            KeyEmitter.spaceRight()
            ok = true

        case ActionCatalog.ID.dockActivate:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                ok = ZoneActions.activateDockApp(app)
            } else {
                ok = false
            }
        case ActionCatalog.ID.dockHide:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                ok = ZoneActions.hideDockApp(app)
            } else {
                ok = false
            }
        case ActionCatalog.ID.dockNewWindow:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                ZoneActions.newWindowForDockApp(app)
                ok = true
            } else {
                ok = false
            }
        case ActionCatalog.ID.dockQuit:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                ZoneActions.quitDockApp(app)
                ok = true
            } else {
                ok = false
            }

        case ActionCatalog.ID.menubarNext:
            ZoneActions.focusNextWindow()
            ok = true
        case ActionCatalog.ID.menubarPrev:
            ZoneActions.focusPreviousWindow()
            ok = true
        case ActionCatalog.ID.menubarHideOthers:
            ZoneActions.hideOtherApps()
            ok = true
        case ActionCatalog.ID.menubarUnminimize:
            ZoneActions.unminimizeFrontmost()
            ok = true

        case ActionCatalog.ID.browserNewTab:
            KeyEmitter.post(keyCode: 17, flags: .maskCommand) // T
            ok = true
        case ActionCatalog.ID.browserCloseTab:
            KeyEmitter.post(keyCode: 13, flags: .maskCommand) // W
            ok = true
        case ActionCatalog.ID.browserNextTab:
            KeyEmitter.post(keyCode: KeyEmitter.Code.tab, flags: .maskControl)
            ok = true
        case ActionCatalog.ID.browserPrevTab:
            KeyEmitter.post(keyCode: KeyEmitter.Code.tab, flags: [.maskControl, .maskShift])
            ok = true
        case ActionCatalog.ID.browserBack:
            KeyEmitter.browserBack()
            ok = true
        case ActionCatalog.ID.browserForward:
            KeyEmitter.browserForward()
            ok = true

        case ActionCatalog.ID.keyCopy:
            KeyEmitter.post(keyCode: 8, flags: .maskCommand) // C
            ok = true
        case ActionCatalog.ID.keyPaste:
            KeyEmitter.post(keyCode: 9, flags: .maskCommand) // V
            ok = true
        case ActionCatalog.ID.keyCut:
            KeyEmitter.post(keyCode: 7, flags: .maskCommand) // X
            ok = true
        case ActionCatalog.ID.keyUndo:
            KeyEmitter.post(keyCode: 6, flags: .maskCommand) // Z
            ok = true
        case ActionCatalog.ID.keyRedo:
            KeyEmitter.post(keyCode: 6, flags: [.maskCommand, .maskShift]) // ⇧⌘Z
            ok = true
        case ActionCatalog.ID.keySelectAll:
            KeyEmitter.post(keyCode: 0, flags: .maskCommand) // A
            ok = true
        case ActionCatalog.ID.keySave:
            KeyEmitter.post(keyCode: 1, flags: .maskCommand) // S
            ok = true
        case ActionCatalog.ID.keyNew:
            KeyEmitter.commandN()
            ok = true
        case ActionCatalog.ID.keyClose:
            KeyEmitter.post(keyCode: 13, flags: .maskCommand) // W
            ok = true
        case ActionCatalog.ID.keyQuit:
            KeyEmitter.commandQ()
            ok = true
        case ActionCatalog.ID.keyHide:
            KeyEmitter.post(keyCode: KeyEmitter.Code.h, flags: .maskCommand)
            ok = true
        case ActionCatalog.ID.keyFind:
            KeyEmitter.post(keyCode: 3, flags: .maskCommand) // F
            ok = true
        case ActionCatalog.ID.keyEscape:
            KeyEmitter.post(keyCode: 53)
            ok = true
        case ActionCatalog.ID.keyDelete:
            KeyEmitter.post(keyCode: 51)
            ok = true
        case ActionCatalog.ID.keyReturn:
            KeyEmitter.post(keyCode: 36)
            ok = true
        case ActionCatalog.ID.keySpace:
            KeyEmitter.post(keyCode: 49)
            ok = true
        case ActionCatalog.ID.keySpotlight:
            KeyEmitter.post(keyCode: 49, flags: .maskCommand) // ⌘Space
            ok = true
        case ActionCatalog.ID.keySwitchApp:
            KeyEmitter.post(keyCode: KeyEmitter.Code.tab, flags: .maskCommand)
            ok = true

        default:
            if let ks = ActionCatalog.parseCustomKeystroke(actionId) {
                KeyEmitter.post(keyCode: ks.keyCode, flags: ks.flags)
                ok = true
            } else if let bundleId = ActionCatalog.parseLaunchApp(actionId) {
                ok = launchApplication(bundleId: bundleId)
            } else if let uuid = ActionCatalog.parseCustomAction(actionId) {
                ok = runCustomAction(uuid: uuid)
            } else {
                Log.warn(.gesture, "Unknown actionId=\(actionId)")
                ok = false
            }
        }

        if ok {
            Haptics.fire(enabled: context.haptics)
            Log.info(.gesture, "action \(actionId) ok")
        } else {
            Log.warn(.gesture, "action \(actionId) failed")
        }
        return ok
    }

    private static func snap(_ layout: WindowLayout, _ context: ActionContext) -> Bool {
        if let w = context.window {
            return WindowManager.shared.snap(window: w, layout: layout, gap: context.gap)
        }
        return WindowManager.shared.snapWindowUnderCursor(layout: layout, gap: context.gap)
    }

    private static func moveDisplay(_ direction: Int, _ context: ActionContext) -> Bool {
        if let w = context.window {
            return WindowManager.shared.moveToAdjacentDisplay(window: w, direction: direction, gap: context.gap)
        }
        return WindowManager.shared.moveFocusedToAdjacentDisplay(direction: direction, gap: context.gap)
    }

    private static func launchApplication(bundleId: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            Log.warn(.gesture, "app.launch: no app for bundleId=\(bundleId)")
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                Log.warn(.gesture, "app.launch failed \(bundleId): \(error.localizedDescription)")
            }
        }
        Log.info(.gesture, "app.launch \(bundleId)")
        return true
    }

    // MARK: - Custom script actions

    /// Runs a user-defined script action.
    ///
    /// Fire-and-forget by design: the gesture pipeline runs on the event tap's thread, so waiting
    /// on a script would stall input. `true` therefore means "dispatched", and script failures are
    /// reported through `Log` rather than through the return value.
    private static func runCustomAction(uuid: UUID) -> Bool {
        guard let def = ActionCatalog.customAction(id: uuid) else {
            // Binding outlived its definition (deleted def, or an imported config). Treat as `none`.
            Log.warn(.gesture, "action.custom: no definition for \(uuid.uuidString)")
            return false
        }
        guard def.isRunnable else {
            Log.warn(.gesture, "action.custom '\(def.displayName)': empty payload")
            return false
        }

        switch def.kind {
        case .shell:
            // `-l` so the script sees the user's normal PATH from their zsh profile.
            runProcess(label: def.displayName, launchPath: "/bin/zsh", arguments: ["-lc", def.payload])
        case .shortcut:
            runProcess(label: def.displayName, launchPath: "/usr/bin/shortcuts", arguments: ["run", def.payload])
        case .appleScript:
            // `osascript` rather than `NSAppleScript`: the latter offers no cancellation, which
            // would make AppleScript the one kind not bounded by `customActionTimeout`. Going
            // through the process path gives all three kinds one deadline and one error log.
            runProcess(label: def.displayName, launchPath: "/usr/bin/osascript", arguments: ["-e", def.payload])
        }
        return true
    }

    /// Spawns a child process off-main with a hard deadline, logging stderr on failure.
    ///
    /// stderr is drained by a `readabilityHandler` *while* this thread waits on the process, so a
    /// chatty script can't fill the pipe buffer and stall until the deadline kills it — the
    /// deadline then measures real hangs rather than output volume. Nothing non-`Sendable` crosses
    /// a concurrency boundary: the process is created and only ever touched inside the dispatched
    /// closure, and the handler talks to this thread through a lock-protected buffer and two
    /// semaphores. A missing binary (e.g. no `shortcuts` on older macOS) surfaces as a `run()`
    /// throw and is logged like any other failure.
    private static func runProcess(label: String, launchPath: String, arguments: [String]) {
        dispatchCustomAction(label: label) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = FileHandle.nullDevice

            let exited = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in exited.signal() }

            // The handler runs on the pipe's own serial queue, so the EOF branch (empty read) is
            // reached exactly once — and that is where it clears itself, which is what makes a
            // post-exit fire impossible. The two paths below that also clear it are mutually
            // exclusive with EOF ever arriving.
            let stderrBuffer = ScriptErrorBuffer()
            let reader = errorPipe.fileHandleForReading
            let drained = DispatchSemaphore(value: 0)
            reader.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else {
                    handle.readabilityHandler = nil
                    drained.signal()
                    return
                }
                stderrBuffer.append(chunk)
            }

            do {
                try process.run()
            } catch {
                // The child never started, so the write end stays open and EOF never arrives.
                reader.readabilityHandler = nil
                Log.warn(.gesture, "action.custom '\(label)': launch failed — \(error.localizedDescription)")
                return
            }

            var timedOut = false
            if exited.wait(timeout: .now() + customActionTimeout) == .timedOut {
                timedOut = true
                // SIGTERM first so a well-behaved script can clean up, then SIGKILL if it ignores
                // it: a script trapping TERM (or stuck in `read`) would otherwise park this thread
                // on the waits below forever.
                process.terminate()
                if exited.wait(timeout: .now() + customActionKillGrace) == .timedOut, process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    exited.wait()
                }
            }

            // The child is gone by now, so its write end is closed and EOF is imminent; the timeout
            // only matters when a surviving grandchild inherited the pipe.
            if drained.wait(timeout: .now() + customActionKillGrace) == .timedOut {
                reader.readabilityHandler = nil
            }
            let errorText = stderrBuffer.text

            if timedOut {
                Log.warn(.gesture, "action.custom '\(label)': timed out after \(Int(customActionTimeout))s — terminated")
            } else if process.terminationStatus != 0 {
                Log.warn(.gesture, "action.custom '\(label)': exit \(process.terminationStatus)\(errorText.isEmpty ? "" : " — \(errorText)")")
            } else {
                Log.info(.gesture, "action.custom '\(label)' ok")
            }
        }
    }
}

/// Concurrent so one slow script doesn't delay the next gesture; `customActionTimeout` bounds how
/// long any single one can occupy a thread, and `customActionSlots` how many can run at once.
private let customActionQueue = DispatchQueue(
    label: "app.sanne.customAction",
    qos: .userInitiated,
    attributes: .concurrent
)

/// Ceiling on simultaneously running scripts. Small on purpose: gestures are human-paced, so
/// wanting more than a handful at once means something is misfiring rather than being used.
private let customActionSlotCount = 4
private let customActionSlots = DispatchSemaphore(value: customActionSlotCount)

/// Runs `work` on `customActionQueue`, capped at `customActionSlotCount` concurrent scripts.
///
/// A gesture bound to a slow script can fire again long before that script finishes, so without a
/// cap one twitchy swipe could spawn dozens of simultaneous processes. The acquire/release pair
/// lives here rather than inside `work` so that an early `return` added to that body later can't
/// leak a slot — `defer` releases it on every path out.
private func dispatchCustomAction(label: String, _ work: @escaping @Sendable () -> Void) {
    // Non-blocking acquire: parking a queue thread until a slot frees would trade process
    // explosion for thread explosion, and a script that finally runs long after the gesture is
    // worse than one that never ran at all — so a full pool drops the invocation and says so.
    guard customActionSlots.wait(timeout: .now()) == .success else {
        Log.warn(.gesture, "action.custom '\(label)': \(customActionSlotCount) scripts already running — skipped")
        return
    }
    customActionQueue.async {
        defer { customActionSlots.signal() }
        work()
    }
}

/// Hard deadline for a single custom action, so a script waiting on input can't leak forever.
private let customActionTimeout: TimeInterval = 10

/// The limits above, readable by the UI.
///
/// Settings explains both numbers to the user, and a description that quietly disagreed with the
/// runner would be worse than none at all — so the copy interpolates these rather than restating
/// them. Kept here, next to the constants it mirrors, and deliberately not on `ActionRunner`, which
/// is `@MainActor`: these are plain values any layer may read.
enum CustomActionLimits {
    /// Seconds a single script may run before it is terminated.
    static let timeoutSeconds = Int(customActionTimeout)
    /// How many scripts may run at once before further triggers are dropped.
    static let concurrentScripts = customActionSlotCount
}

/// Grace given to a script to honour SIGTERM before it is killed, and to stderr to reach EOF after
/// the child is gone.
private let customActionKillGrace: TimeInterval = 1

/// Lock-protected accumulator for a child process's stderr.
///
/// The pipe's `readabilityHandler` appends from its own queue while the launching thread waits on
/// the process, so both ends need the lock; reference semantics let the closure share one buffer
/// without capturing a mutating local.
private final class ScriptErrorBuffer: @unchecked Sendable {
    /// Only the first few KB ever reach a log line, and a runaway script must not grow this
    /// without bound. Keeping the head rather than the tail preserves the first (usually causal)
    /// error message.
    private static let limit = 4096

    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard data.count < Self.limit else { return }
        data.append(chunk.prefix(Self.limit - data.count))
    }

    var text: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(decoding: snapshot, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
