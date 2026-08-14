import Foundation

/// Bundled Sanne Standard JSON. Shared by `ConfigStore` and tests so the file cannot
/// silently drift from what the app actually loads.
enum BundledPreset {
    static func standardURL() -> URL? {
        #if SWIFT_PACKAGE
        let urls = [
            Bundle.module.url(forResource: "sanne.standard", withExtension: "json", subdirectory: "Presets"),
            Bundle.module.url(forResource: "sanne.standard", withExtension: "json"),
        ]
        return urls.compactMap { $0 }.first
        #else
        return nil
        #endif
    }

    static func loadStandard() -> SanneConfig? {
        guard let url = standardURL(),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(SanneConfig.self, from: data)
    }
}
