import Foundation
import os

/// Cheap in-process counters for the recognition hot path. Debug Log reads them; they are
/// never written to the log file.
enum PerfCounters {
    private static let lock = OSAllocatedUnfairLock()

    private static var mmCallbacks: UInt64 = 0
    private static var trackpadCallbacks: UInt64 = 0
    private static var mainHops: UInt64 = 0
    private static var configCopies: UInt64 = 0
    private static var bindingResolves: UInt64 = 0
    private static var axSetFrame: UInt64 = 0
    private static var logAppends: UInt64 = 0
    private static var configSaves: UInt64 = 0

    static func incMMCallbacks() { lock.withLock { mmCallbacks &+= 1 } }
    static func incTrackpadCallbacks() { lock.withLock { trackpadCallbacks &+= 1 } }
    static func incMainHops() { lock.withLock { mainHops &+= 1 } }
    static func incConfigCopies() { lock.withLock { configCopies &+= 1 } }
    static func incBindingResolves() { lock.withLock { bindingResolves &+= 1 } }
    static func incAXSetFrame() { lock.withLock { axSetFrame &+= 1 } }
    static func incLogAppends() { lock.withLock { logAppends &+= 1 } }
    static func incConfigSaves() { lock.withLock { configSaves &+= 1 } }

    static func reset() {
        lock.withLock {
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
        lock.withLock {
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
