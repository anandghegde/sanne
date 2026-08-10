import Foundation
import Combine

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    /// `didSet` keeps `ActionCatalog`'s lock-protected mirror current for every assignment path
    /// (load / update / import / reset), so nonisolated lookups never see a stale script list.
    @Published private(set) var config: SanneConfig = .default {
        didSet { ActionCatalog.syncCustomActions(config.customActions) }
    }

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Sanne", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(SanneConfig.self, from: data)
        {
            config = decoded
            Log.info(.config, "Loaded config from \(self.fileURL.path)")
            return
        }
        if let bundled = loadBundledStandard() {
            config = bundled
            Log.info(.config, "Loaded bundled Sanne Standard preset")
        } else {
            config = .default
            Log.info(.config, "Using in-code defaults")
        }
        save()
    }

    func save() {
        do {
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.error(.config, "Failed to save config: \(error.localizedDescription)")
        }
    }

    func update(_ mutate: (inout SanneConfig) -> Void) {
        var next = config
        mutate(&next)
        config = next
        save()
        NotificationCenter.default.post(name: .sanneConfigDidChange, object: nil)
    }

    func resetToStandard() {
        if let bundled = loadBundledStandard() {
            config = bundled
        } else {
            config = .default
        }
        config.paused = false
        config.gestureOverrides = [:]
        // Per-app bindings are remaps too, so "Reset to Standard" has to clear them as well —
        // otherwise a gesture keeps behaving differently in one app with no visible reason why.
        config.appGestureOverrides = [:]
        save()
        NotificationCenter.default.post(name: .sanneConfigDidChange, object: nil)
    }

    /// Pretty-printed JSON of the current config (for export / backup).
    func exportData() throws -> Data {
        try encoder.encode(config)
    }

    /// Replace config from imported JSON. Keeps `paused` as currently set unless the file sets it.
    func importData(_ data: Data) throws {
        let decoded = try decoder.decode(SanneConfig.self, from: data)
        let wasPaused = config.paused
        config = decoded
        // Don't surprise the user by unpausing/pausing from a shared preset unless explicit.
        if decoded.paused == false {
            config.paused = wasPaused
        }
        save()
        NotificationCenter.default.post(name: .sanneConfigDidChange, object: nil)
        Log.info(.config, "Imported config (presetId=\(config.presetId))")
    }

    func exportToFile(url: URL) throws {
        let data = try exportData()
        try data.write(to: url, options: .atomic)
        Log.info(.config, "Exported config to \(url.path)")
    }

    func importFromFile(url: URL) throws {
        let data = try Data(contentsOf: url)
        try importData(data)
    }

    private func loadBundledStandard() -> SanneConfig? {
        #if SWIFT_PACKAGE
        let bundleURLs = [
            Bundle.module.url(forResource: "sanne.standard", withExtension: "json", subdirectory: "Presets"),
            Bundle.module.url(forResource: "sanne.standard", withExtension: "json"),
        ]
        for url in bundleURLs.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? decoder.decode(SanneConfig.self, from: data)
            {
                return decoded
            }
        }
        #endif
        return nil
    }
}

extension Notification.Name {
    static let sanneConfigDidChange = Notification.Name("sanneConfigDidChange")
}
