import AppKit

enum CompetingApps {
    /// Known gesture apps that may conflict with Sanne.
    static let knownBundleIDs: [String: String] = [
        "com.hegenberg.BetterTouchTool": "BetterTouchTool",
        "com.loonggg.Swish": "Swish",
        "com.highlyopinionated.swish": "Swish",
        "com.knollsoft.Hookshot": "Hookshot / Rectangle Pro",
        "com.knollsoft.Rectangle": "Rectangle",
    ]

    static func runningConflicts() -> [String] {
        let running = NSWorkspace.shared.runningApplications
        var names: [String] = []
        for app in running {
            guard let bid = app.bundleIdentifier else { continue }
            if let name = knownBundleIDs[bid] {
                names.append(name)
                continue
            }
            // Heuristic match on localized name
            let n = (app.localizedName ?? "").lowercased()
            if n.contains("multitouch") || n.contains("taptoclick") || n.contains("bettertouch")
                || n.contains("swish") || n == "middle"
            {
                names.append(app.localizedName ?? bid)
            }
        }
        return Array(Set(names)).sorted()
    }
}
