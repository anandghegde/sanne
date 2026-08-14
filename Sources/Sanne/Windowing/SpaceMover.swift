import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

/// Feature-flagged window → Space move. Private CGS symbols are loaded with `dlsym`
/// and every failure path returns false so the runner can HUD.
enum SpaceMover {
    enum Failure: Error, Equatable {
        case disabled
        case noWindow
        case apiUnavailable
        case noNeighbor
        case moveFailed
    }

    /// `direction` is −1 previous / +1 next on the current display.
    static func move(
        window: AXUIElement?,
        direction: Int,
        enabled: Bool
    ) -> Result<Void, Failure> {
        guard enabled else { return .failure(.disabled) }
        guard Permissions.isAccessibilityTrusted else { return .failure(.noWindow) }
        guard let window else { return .failure(.noWindow) }
        guard let identity = WindowIdentityResolver.identity(of: window) else {
            return .failure(.noWindow)
        }
        guard let api = CGS.self_ else { return .failure(.apiUnavailable) }

        let cid = api.mainConnection()
        var spacesRef: Unmanaged<CFArray>?
        let copyErr = api.copyManagedDisplaySpaces(cid, &spacesRef)
        guard copyErr == 0, let spaces = spacesRef?.takeRetainedValue() as? [[String: Any]] else {
            return .failure(.apiUnavailable)
        }

        guard let neighbor = neighborSpaceID(in: spaces, direction: direction) else {
            return .failure(.noNeighbor)
        }

        let ids = [NSNumber(value: identity.windowNumber)] as CFArray
        let moveErr = api.moveWindows(cid, ids, neighbor)
        if moveErr != 0 {
            Log.warn(.window, "CGSMoveWindowsToManagedSpace err=\(moveErr) space=\(neighbor)")
            return .failure(.moveFailed)
        }
        Log.info(.window, "moved window \(identity.windowNumber) to space \(neighbor)")
        return .success(())
    }

    static func hudTitle(for failure: Failure) -> String {
        switch failure {
        case .disabled: return "Spaces move is off"
        case .noWindow: return "No window"
        case .apiUnavailable: return "Can't move Space"
        case .noNeighbor: return "No Space that way"
        case .moveFailed: return "Can't move Space"
        }
    }

    /// Pure: pick the adjacent user Space on the first display that has a current Space.
    static func neighborSpaceID(in displays: [[String: Any]], direction: Int) -> Int64? {
        for display in displays {
            guard let current = spaceID(display["Current Space"]),
                  let list = display["Spaces"] as? [[String: Any]]
            else { continue }
            let user = list.compactMap { entry -> Int64? in
                // type 0 = user Space; 4 = fullscreen. Skip non-user.
                if let type = entry["type"] as? Int, type != 0 { return nil }
                return spaceID(entry)
            }
            guard let idx = user.firstIndex(of: current) else { continue }
            let next = idx + (direction >= 0 ? 1 : -1)
            guard user.indices.contains(next) else { return nil }
            return user[next]
        }
        return nil
    }

    private static func spaceID(_ value: Any?) -> Int64? {
        guard let dict = value as? [String: Any] else { return nil }
        if let n = dict["id64"] as? Int64 { return n }
        if let n = dict["id64"] as? Int { return Int64(n) }
        if let n = dict["ManagedSpaceID"] as? Int64 { return n }
        if let n = dict["ManagedSpaceID"] as? Int { return Int64(n) }
        return nil
    }
}

// MARK: - Private CGS (optional)

private struct CGS {
    typealias MainConnection = @convention(c) () -> Int32
    typealias CopySpaces = @convention(c) (Int32, UnsafeMutablePointer<Unmanaged<CFArray>?>) -> Int32
    typealias MoveWindows = @convention(c) (Int32, CFArray, Int64) -> Int32

    let mainConnection: MainConnection
    let copyManagedDisplaySpaces: CopySpaces
    let moveWindows: MoveWindows

    static let self_: CGS? = {
        let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
        guard let handle else { return nil }
        guard
            let main = dlsym(handle, "CGSMainConnectionID"),
            let copy = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
            let move = dlsym(handle, "CGSMoveWindowsToManagedSpace")
        else { return nil }
        return CGS(
            mainConnection: unsafeBitCast(main, to: MainConnection.self),
            copyManagedDisplaySpaces: unsafeBitCast(copy, to: CopySpaces.self),
            moveWindows: unsafeBitCast(move, to: MoveWindows.self)
        )
    }()
}
