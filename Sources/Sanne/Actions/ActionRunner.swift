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

struct ActionRunResult {
    var ok: Bool
    var hudTitle: String?
    var errorTitle: String?
}

/// Executes catalog action IDs.
@MainActor
enum ActionRunner {
    @discardableResult
    static func run(_ actionId: String, context: ActionContext) -> Bool {
        execute(actionId, context: context).ok
    }

    @discardableResult
    static func execute(_ actionId: String, context: ActionContext) -> ActionRunResult {
        if actionId == ActionCatalog.ID.none
            || actionId == ActionCatalog.ID.drag
            || actionId == ActionCatalog.ID.moveWindow
            || actionId == ActionCatalog.ID.resizeWindow
        {
            return ActionRunResult(ok: false, hudTitle: nil, errorTitle: nil)
        }

        var hudTitle: String?
        var errorTitle: String?
        let ok: Bool
        if let layout = ActionCatalog.snapLayout(for: actionId) {
            let result = snap(layout, context)
            ok = result.ok
            if result.restored {
                hudTitle = "Restore"
            } else if !ok {
                errorTitle = "No window"
            }
        } else if let windowResult = runWindow(actionId, context) {
            ok = windowResult.ok
            hudTitle = windowResult.hudTitle
            errorTitle = windowResult.errorTitle
        } else if let inputResult = runInput(actionId, context) {
            ok = inputResult.ok
            hudTitle = inputResult.hudTitle
            errorTitle = inputResult.errorTitle
        } else if let systemResult = runSystem(actionId, context) {
            ok = systemResult.ok
            hudTitle = systemResult.hudTitle
            errorTitle = systemResult.errorTitle
        } else {
            let custom = runCustom(actionId, context)
            ok = custom.ok
            hudTitle = custom.hudTitle
            errorTitle = custom.errorTitle
        }

        if hudTitle == nil, ok {
            hudTitle = ActionCatalog.hudTitle(for: actionId)
        }

        if ok {
            Haptics.fire(enabled: context.haptics)
            Log.info(.gesture, "action \(actionId) ok")
        } else {
            Log.warn(.gesture, "action \(actionId) failed")
        }
        return ActionRunResult(ok: ok, hudTitle: hudTitle, errorTitle: errorTitle)
    }

    private static func runWindow(_ actionId: String, _ context: ActionContext) -> ActionRunResult? {
        switch actionId {
        case ActionCatalog.ID.restore:
            let ok: Bool
            if let w = context.window {
                ok = WindowManager.shared.restoreFrame(of: w)
            } else {
                ok = WindowManager.shared.restoreFocused()
            }
            return ActionRunResult(ok: ok, hudTitle: ok ? "Restore" : nil, errorTitle: ok ? nil : "No window")
        case ActionCatalog.ID.minimize:
            let ok = context.window.map { WindowManager.shared.minimize($0) } ?? WindowManager.shared.minimizeUnderCursor()
            return ActionRunResult(ok: ok, hudTitle: nil, errorTitle: ok ? nil : "No window")
        case ActionCatalog.ID.close:
            let ok = context.window.map { WindowManager.shared.close($0) } ?? WindowManager.shared.closeUnderCursor()
            return ActionRunResult(ok: ok, hudTitle: nil, errorTitle: ok ? nil : "No window")
        case ActionCatalog.ID.fullscreen:
            let ok = context.window.map { WindowManager.shared.fullscreen($0) } ?? WindowManager.shared.fullscreenUnderCursor()
            return ActionRunResult(ok: ok, hudTitle: nil, errorTitle: ok ? nil : "No window")
        case ActionCatalog.ID.moveDisplayLeft:
            return ActionRunResult(ok: moveDisplay(-1, context), hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.moveDisplayRight:
            return ActionRunResult(ok: moveDisplay(1, context), hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.moveSpaceLeft:
            let result = moveSpace(-1, context)
            return ActionRunResult(ok: result.ok, hudTitle: nil, errorTitle: result.error)
        case ActionCatalog.ID.moveSpaceRight:
            let result = moveSpace(1, context)
            return ActionRunResult(ok: result.ok, hudTitle: nil, errorTitle: result.error)
        default:
            return nil
        }
    }

    private static func runInput(_ actionId: String, _ context: ActionContext) -> ActionRunResult? {
        switch actionId {
        case ActionCatalog.ID.clickLeft:
            ClickEmitter.click(.left, clickCount: max(1, context.clickCount))
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.clickRight:
            ClickEmitter.click(.right, clickCount: 1)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.clickMiddle:
            ClickEmitter.click(.middle, clickCount: 1)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.browserNewTab:
            KeyEmitter.post(keyCode: 17, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.browserCloseTab:
            KeyEmitter.post(keyCode: 13, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.browserNextTab:
            KeyEmitter.post(keyCode: KeyEmitter.Code.tab, flags: .maskControl)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.browserPrevTab:
            KeyEmitter.post(keyCode: KeyEmitter.Code.tab, flags: [.maskControl, .maskShift])
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.browserBack:
            KeyEmitter.browserBack()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.browserForward:
            KeyEmitter.browserForward()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyCopy:
            KeyEmitter.post(keyCode: 8, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyPaste:
            KeyEmitter.post(keyCode: 9, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyCut:
            KeyEmitter.post(keyCode: 7, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyUndo:
            KeyEmitter.post(keyCode: 6, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyRedo:
            KeyEmitter.post(keyCode: 6, flags: [.maskCommand, .maskShift])
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keySelectAll:
            KeyEmitter.post(keyCode: 0, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keySave:
            KeyEmitter.post(keyCode: 1, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyNew:
            KeyEmitter.commandN()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyClose:
            KeyEmitter.post(keyCode: 13, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyQuit:
            KeyEmitter.commandQ()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyHide:
            KeyEmitter.post(keyCode: KeyEmitter.Code.h, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyFind:
            KeyEmitter.post(keyCode: 3, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyEscape:
            KeyEmitter.post(keyCode: 53)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyDelete:
            KeyEmitter.post(keyCode: 51)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keyReturn:
            KeyEmitter.post(keyCode: 36)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keySpace:
            KeyEmitter.post(keyCode: 49)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keySpotlight:
            KeyEmitter.post(keyCode: 49, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.keySwitchApp:
            KeyEmitter.post(keyCode: KeyEmitter.Code.tab, flags: .maskCommand)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        default:
            return nil
        }
    }

    private static func runSystem(_ actionId: String, _ context: ActionContext) -> ActionRunResult? {
        switch actionId {
        case ActionCatalog.ID.missionControl:
            KeyEmitter.missionControl()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.appExpose:
            KeyEmitter.appExpose()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.spaceLeft:
            KeyEmitter.spaceLeft()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.spaceRight:
            KeyEmitter.spaceRight()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.dockActivate:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                return ActionRunResult(ok: ZoneActions.activateDockApp(app), hudTitle: nil, errorTitle: nil)
            }
            return ActionRunResult(ok: false, hudTitle: nil, errorTitle: "No window")
        case ActionCatalog.ID.dockHide:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                return ActionRunResult(ok: ZoneActions.hideDockApp(app), hudTitle: nil, errorTitle: nil)
            }
            return ActionRunResult(ok: false, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.dockNewWindow:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                ZoneActions.newWindowForDockApp(app)
                return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
            }
            return ActionRunResult(ok: false, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.dockQuit:
            if let app = context.dockApp ?? ZoneActions.dockApp() {
                ZoneActions.quitDockApp(app)
                return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
            }
            return ActionRunResult(ok: false, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.menubarNext:
            ZoneActions.focusNextWindow()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.menubarPrev:
            ZoneActions.focusPreviousWindow()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.menubarHideOthers:
            ZoneActions.hideOtherApps()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        case ActionCatalog.ID.menubarUnminimize:
            ZoneActions.unminimizeFrontmost()
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        default:
            return nil
        }
    }

    private static func runCustom(_ actionId: String, _ context: ActionContext) -> ActionRunResult {
        _ = context
        var errorTitle: String?
        if let ks = ActionCatalog.parseCustomKeystroke(actionId) {
            KeyEmitter.post(keyCode: ks.keyCode, flags: ks.flags)
            return ActionRunResult(ok: true, hudTitle: nil, errorTitle: nil)
        }
        if let bundleId = ActionCatalog.parseLaunchApp(actionId) {
            let ok = launchApplication(bundleId: bundleId)
            return ActionRunResult(ok: ok, hudTitle: ok ? ActionCatalog.hudTitle(for: actionId) : nil, errorTitle: nil)
        }
        if let uuid = ActionCatalog.parseCustomAction(actionId) {
            let ok = runCustomAction(uuid: uuid, errorTitle: &errorTitle)
            return ActionRunResult(ok: ok, hudTitle: ok ? ActionCatalog.hudTitle(for: actionId) : nil, errorTitle: errorTitle)
        }
        Log.warn(.gesture, "Unknown actionId=\(actionId)")
        return ActionRunResult(ok: false, hudTitle: nil, errorTitle: nil)
    }

    private static func snap(_ layout: WindowLayout, _ context: ActionContext) -> (ok: Bool, restored: Bool) {
        if let w = context.window {
            return WindowManager.shared.snapDetailed(window: w, layout: layout, gap: context.gap)
        }
        return WindowManager.shared.snapWindowUnderCursorDetailed(layout: layout, gap: context.gap)
    }

    private static func moveDisplay(_ direction: Int, _ context: ActionContext) -> Bool {
        if let w = context.window {
            return WindowManager.shared.moveToAdjacentDisplay(window: w, direction: direction, gap: context.gap)
        }
        return WindowManager.shared.moveFocusedToAdjacentDisplay(direction: direction, gap: context.gap)
    }

    private static func moveSpace(_ direction: Int, _ context: ActionContext) -> (ok: Bool, error: String?) {
        let enabled = ConfigStore.shared.config.experimental.windowToSpace
        let window = context.window ?? WindowManager.shared.focusedWindow()
        switch SpaceMover.move(window: window, direction: direction, enabled: enabled) {
        case .success:
            return (true, nil)
        case .failure(let failure):
            return (false, SpaceMover.hudTitle(for: failure))
        }
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
    /// Fire-and-forget: `true` means dispatched. Failures are logged; a full pool is a HUD error.
    private static func runCustomAction(uuid: UUID, errorTitle: inout String?) -> Bool {
        guard let def = ActionCatalog.customAction(id: uuid) else {
            Log.warn(.gesture, "action.custom: no definition for \(uuid.uuidString)")
            errorTitle = "No window"
            return false
        }
        guard def.isRunnable else {
            Log.warn(.gesture, "action.custom '\(def.displayName)': empty payload")
            errorTitle = "No window"
            return false
        }

        switch def.kind {
        case .shell:
            // `zsh -c` on purpose: a login shell would load `.zprofile` on every gesture.
            runProcess(label: def.displayName, launchPath: "/bin/zsh", arguments: ["-c", def.payload])
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
        Task { @MainActor in HUDController.shared.show(title: "Already running") }
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
