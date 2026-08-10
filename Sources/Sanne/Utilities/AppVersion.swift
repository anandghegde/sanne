import Foundation

/// Marketing / build version shown in About and logs.
enum AppVersion {
    /// `CFBundleShortVersionString` from the packaged app, else `0.1.0` for `swift run`.
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
    }

    /// `CFBundleVersion` build number when packaged.
    static var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    /// e.g. `0.1.0` or `0.1.0 (202608011200)`.
    static var display: String {
        if let build, !build.isEmpty, build != marketing {
            return "\(marketing) (\(build))"
        }
        return marketing
    }
}
