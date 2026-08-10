import AppKit

enum Haptics {
    @MainActor
    static func fire(enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}
