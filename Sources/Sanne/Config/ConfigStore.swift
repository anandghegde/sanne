import AppKit
import Combine
import Foundation

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    /// `didSet` keeps `ActionCatalog`'s lock-protected mirror current for every assignment path
    /// (load / update / import / reset), so nonisolated lookups never see a stale script list.
    @Published private(set) var config: SanneConfig = .default {
        didSet { ActionCatalog.syncCustomActions(config.customActions) }
    }

    /// Option held at launch: Standard is in memory, the on-disk file was not touched.
    @Published private(set) var safeMode = false

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()
    private var saveGeneration: UInt64 = 0
    private var terminateObserver: NSObjectProtocol?

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Sanne", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")
        load()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in ConfigStore.shared.flushPendingSave() }
        }
    }

    func load() {
        if SafeMode.isActive {
            safeMode = true
            if let bundled = BundledPreset.loadStandard() {
                var decoded = bundled
                if decoded.version < 2 { decoded.migrateToSlotEnablement() }
                config = decoded
            } else {
                var fallback = SanneConfig.default
                fallback.migrateToSlotEnablement()
                config = fallback
            }
            config.paused = false
            WelcomePrefs.adoptExistingInstall()
            Log.warn(.config, "Safe mode — Option held at launch; user config not loaded")
            return
        }

        let existed = FileManager.default.fileExists(atPath: fileURL.path)
        if existed, let data = try? Data(contentsOf: fileURL) {
            do {
                var decoded = try decoder.decode(SanneConfig.self, from: data)
                if decoded.version < 2 {
                    decoded.migrateToSlotEnablement()
                    WelcomePrefs.adoptExistingInstall()
                    config = decoded
                    save()
                    Log.info(.config, "Migrated config to v2 (slot enablement) at \(self.fileURL.path)")
                    return
                }
                WelcomePrefs.adoptExistingInstall()
                config = decoded
                Log.info(.config, "Loaded config from \(self.fileURL.path)")
                return
            } catch {
                do {
                    let bak = try ConfigFileRecovery.writeBackup(data: data, fileURL: fileURL)
                    Log.error(
                        .config,
                        "Config decode failed (\(error.localizedDescription)); original bytes saved to \(bak.path)"
                    )
                } catch {
                    Log.error(.config, "Config decode failed and backup write failed: \(error.localizedDescription)")
                }
                WelcomePrefs.adoptExistingInstall()
            }
        } else {
            WelcomePrefs.markFreshInstall()
        }
        if let bundled = BundledPreset.loadStandard() {
            config = bundled
            Log.info(.config, "Loaded bundled Sanne Standard preset")
        } else {
            config = .default
            Log.info(.config, "Using in-code defaults")
        }
        save()
    }

    func save() {
        if safeMode {
            Log.debug(.config, "Safe mode — skip writing config.json")
            return
        }
        do {
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
            PerfCounters.incConfigSaves()
        } catch {
            Log.error(.config, "Failed to save config: \(error.localizedDescription)")
        }
    }

    func update(_ mutate: (inout SanneConfig) -> Void) {
        var next = config
        mutate(&next)
        config = next
        scheduleSave()
        NotificationCenter.default.post(name: .sanneConfigDidChange, object: nil)
    }

    private func scheduleSave() {
        saveGeneration += 1
        let token = saveGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard token == saveGeneration else { return }
            save()
        }
    }

    /// Write immediately and cancel a pending debounce (export / quit / import / reset).
    func flushPendingSave() {
        saveGeneration += 1
        save()
    }

    func flushForTests() {
        flushPendingSave()
    }

    func resetToStandard() {
        preserveCurrentConfig()
        if let bundled = BundledPreset.loadStandard() {
            config = bundled
        } else {
            config = .default
        }
        config.paused = false
        config.gestureOverrides = [:]
        // Per-app bindings are remaps too, so "Reset to Standard" has to clear them as well —
        // otherwise a gesture keeps behaving differently in one app with no visible reason why.
        config.appGestureOverrides = [:]
        config.presetId = SannePreset.standardId
        config.migrateToSlotEnablement()
        flushPendingSave()
        NotificationCenter.default.post(name: .sanneConfigDidChange, object: nil)
    }

    func applyPreset(_ preset: SannePreset, keepActionRemaps: Bool) {
        update { cfg in
            preset.apply(to: &cfg, keepActionRemaps: keepActionRemaps)
        }
        Log.info(.config, "Applied preset \(preset.id)")
    }

    /// Pretty-printed JSON of the current config (for export / backup).
    func exportData() throws -> Data {
        flushPendingSave()
        return try encoder.encode(config)
    }

    /// Replace config from imported JSON. Keeps `paused` as currently set unless the file sets it.
    func importData(_ data: Data) throws {
        let decoded = try decoder.decode(SanneConfig.self, from: data)
        preserveCurrentConfig()
        let wasPaused = config.paused
        config = decoded
        // Don't surprise the user by unpausing/pausing from a shared preset unless explicit.
        if decoded.paused == false {
            config.paused = wasPaused
        }
        flushPendingSave()
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

    /// Keep one recoverable copy before destructive replacement operations.
    private func preserveCurrentConfig() {
        guard !safeMode else { return }
        do {
            let data = try encoder.encode(config)
            let backup = ConfigFileRecovery.backupURL(for: fileURL)
            try data.write(to: backup, options: .atomic)
            Log.info(.config, "Backed up current config to \(backup.path)")
        } catch {
            Log.warn(.config, "Could not back up current config: \(error.localizedDescription)")
        }
    }

}

enum ConfigFileRecovery {
    static func backupURL(for fileURL: URL) -> URL {
        fileURL.appendingPathExtension("bak")
    }

    /// Copy the original bytes to `config.json.bak` before Standard overwrites the live file.
    @discardableResult
    static func writeBackup(data: Data, fileURL: URL) throws -> URL {
        let bak = backupURL(for: fileURL)
        try data.write(to: bak, options: .atomic)
        return bak
    }
}

extension Notification.Name {
    static let sanneConfigDidChange = Notification.Name("sanneConfigDidChange")
}
