import Foundation

/// GitHub Releases check. No Sparkle — one GET, compare tags, open the release page.
enum UpdateChecker {
    static let githubOwner = "anandghegde"
    static let githubRepo = "sanne"
    static let releasesPage = URL(string: "https://github.com/anandghegde/sanne/releases")!

    static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
    }

    struct Release: Equatable {
        var tag: String
        var htmlURL: URL
    }

    enum Outcome: Equatable {
        case upToDate(current: String)
        case available(Release)
        case failed(String)
    }

    /// Compare dotted marketing versions (`1.2.3`). Missing segments are 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = numericParts(candidate)
        let b = numericParts(current)
        let n = max(a.count, b.count)
        for i in 0..<n {
            let lhs = i < a.count ? a[i] : 0
            let rhs = i < b.count ? b[i] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    static func parseLatest(from data: Data) -> Release? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let tag = obj["tag_name"] as? String, !tag.isEmpty else { return nil }
        let urlString = obj["html_url"] as? String
        let url = urlString.flatMap(URL.init(string:)) ?? releasesPage
        return Release(tag: tag, htmlURL: url)
    }

    static func evaluate(latest: Release, current: String) -> Outcome {
        let latestNum = stripV(latest.tag)
        if isNewer(latestNum, than: stripV(current)) {
            return .available(latest)
        }
        return .upToDate(current: current)
    }

    static func stripV(_ raw: String) -> String {
        raw.hasPrefix("v") || raw.hasPrefix("V")
            ? String(raw.dropFirst())
            : raw
    }

    private static func numericParts(_ version: String) -> [Int] {
        stripV(version)
            .split(separator: ".")
            .map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}
