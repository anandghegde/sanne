import Foundation

struct WindowIdentity: Hashable {
    var pid: pid_t
    var title: String
}

final class RestoreStore: @unchecked Sendable {
    private var frames: [WindowIdentity: CGRect] = [:]
    private let lock = NSLock()

    func remember(_ id: WindowIdentity, frame: CGRect) {
        lock.lock()
        if frames[id] == nil {
            frames[id] = frame
        }
        lock.unlock()
    }

    func restore(_ id: WindowIdentity) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        let f = frames[id]
        frames[id] = nil
        return f
    }

    func clear(_ id: WindowIdentity) {
        lock.lock()
        frames[id] = nil
        lock.unlock()
    }
}
