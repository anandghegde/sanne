import Foundation
import ServiceManagement

/// Login item registration via `SMAppService` (macOS 13+).
/// Works reliably only for a real `.app` bundle (not raw `swift run` binaries).
enum LaunchAtLogin {
    enum Status: String {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound
        case unknown
    }

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }

    static var isEnabled: Bool { status == .enabled }

    /// Whether the process looks like a proper app bundle (needed for SMAppService).
    static var isBundledApp: Bool {
        let path = Bundle.main.bundlePath
        return path.hasSuffix(".app") || (Bundle.main.bundleURL.pathExtension == "app")
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    return .success(())
                }
                try SMAppService.mainApp.register()
                Log.info(.app, "Launch at login registered (status=\(status.rawValue))")
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    return .success(())
                }
                try SMAppService.mainApp.unregister()
                Log.info(.app, "Launch at login unregistered")
            }
            return .success(())
        } catch {
            Log.error(.app, "Launch at login failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Sync SMAppService with the config flag. No-op failures are logged.
    static func apply(desired: Bool) {
        guard isBundledApp else {
            if desired {
                Log.warn(.app, "Launch at login requested but process is not a .app bundle — package Sanne.app first")
            }
            return
        }
        let currently = isEnabled
        if desired != currently {
            _ = setEnabled(desired)
        }
    }
}
