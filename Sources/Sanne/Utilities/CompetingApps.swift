import AppKit

enum CompetingApps {
    /// Known gesture apps that may conflict with Sanne.
    static let knownBundleIDs: [String: String] = [
        "com.hegenberg.BetterTouchTool": "BetterTouchTool",
        "com.brassmonkery.Multitouch": "Multitouch",
        "com.larabr.taptoclick": "TapToClick",
        "app.taptoclick.TapToClick": "TapToClick",
        "com.taptoclick.TapToClick": "TapToClick",
        "com.loonggg.Swish": "Swish",
        "com.highlyopinionated.swish": "Swish",
        "com.knollsoft.Hookshot": "Hookshot / Rectangle Pro",
        "com.knollsoft.Rectangle": "Rectangle",
        "com.rouge41.middleClick": "MiddleClick",
    ]

    /// Name-only fallback after the bundle-id table. Does **not** match `"middle"` —
    /// that flagged unrelated apps.
    static func match(bundleId: String?, localizedName: String?) -> String? {
        if let bundleId, let name = knownBundleIDs[bundleId] {
            return name
        }
        let n = (localizedName ?? "").lowercased()
        guard !n.isEmpty else { return nil }
        if n.contains("multitouch") { return localizedName ?? "Multitouch" }
        if n.contains("taptoclick") { return localizedName ?? "TapToClick" }
        if n.contains("bettertouch") { return localizedName ?? "BetterTouchTool" }
        if n.contains("swish") { return localizedName ?? "Swish" }
        return nil
    }

    static func runningConflicts() -> [String] {
        var names: [String] = []
        for app in NSWorkspace.shared.runningApplications {
            if let name = match(bundleId: app.bundleIdentifier, localizedName: app.localizedName) {
                names.append(name)
            }
        }
        return Array(Set(names)).sorted()
    }
}
