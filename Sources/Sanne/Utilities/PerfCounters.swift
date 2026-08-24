import Foundation

/// Cheap in-process counters for the recognition hot path. Debug Log reads them; they are
/// never written to the log file.
enum PerfCounters {
    /// NSLock instead of OSAllocatedUnfairLock: the latter needs macOS 13+, Sanne targets 12.
    private static let lock = NSLock()

    private static func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static var mmCallbacks: UInt64 = 0
    private static var trackpadCallbacks: UInt64 = 0
    private static var mainHops: UInt64 = 0
    private static var configCopies: UInt64 = 0
    private static var bindingResolves: UInt64 = 0
    private static var axSetFrame: UInt64 = 0
    private static var logAppends: UInt64 = 0
    private static var configSaves: UInt64 = 0

    static func incMMCallbacks() { withLock { mmCallbacks &+= 1 } }
    static func incTrackpadCallbacks() { withLock { trackpadCallbacks &+= 1 } }
    static func incMainHops() { withLock { mainHops &+= 1 } }
    static func incConfigCopies() { withLock { configCopies &+= 1 } }
    static func incBindingResolves() { withLock { bindingResolves &+= 1 } }
    static func incAXSetFrame() { withLock { axSetFrame &+= 1 } }
    static func incLogAppends() { withLock { logAppends &+= 1 } }
    static func incConfigSaves() { withLock { configSaves &+= 1 } }

    static func reset() {
        withLock {
            mmCallbacks = 0
            trackpadCallbacks = 0
            mainHops = 0
            configCopies = 0
            bindingResolves = 0
            axSetFrame = 0
            logAppends = 0
            configSaves = 0
        }
    }

    static func snapshotLine() -> String {
        withLock {
            "mm=\(mmCallbacks) tp=\(trackpadCallbacks) main=\(mainHops) copies=\(configCopies) resolve=\(bindingResolves) ax=\(axSetFrame) log=\(logAppends)"
        }
    }
}

enum MainHop {
    /// Counted hop to the main queue for AppKit / AX / HUD / clicks.
    static func async(_ body: @escaping @MainActor () -> Void) {
        PerfCounters.incMainHops()
        DispatchQueue.main.async { body() }
    }
}
