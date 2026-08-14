import Foundation

/// Built-in enablement maps. `presetId` selects which slots are on when no override exists.
struct SannePreset: Equatable, Identifiable {
    struct Masters: Equatable {
        var magicMouse: Bool
        var titlebar: Bool
        var dock: Bool
        var menubar: Bool
        var keyboard: Bool
    }

    let id: String
    let title: String
    let detail: String
    let masters: Masters
    let enabledSlotIds: Set<String>

    static let standardId = "sanne.standard"
    static let minimalId = "sanne.minimal"

    static let standard = SannePreset(
        id: standardId,
        title: "Sanne Standard",
        detail: "Opinionated defaults (recommended).",
        masters: Masters(
            magicMouse: true,
            titlebar: true,
            dock: true,
            menubar: true,
            keyboard: true
        ),
        enabledSlotIds: Set(
            GestureSlots.all
                .filter { GestureSlots.defaultEnabled(for: $0.legacyGate) }
                .map(\.id)
        )
    )

    /// Taps + halves only. Dock, menubar, keyboard, free-space extras, and power titlebar slots stay off.
    static let minimal = SannePreset(
        id: minimalId,
        title: "Minimal",
        detail: "Taps + halves only.",
        masters: Masters(
            magicMouse: true,
            titlebar: true,
            dock: false,
            menubar: false,
            keyboard: false
        ),
        enabledSlotIds: [
            GestureSlots.ID.mmLeft,
            GestureSlots.ID.mmRight,
            GestureSlots.ID.mmMiddle2,
            GestureSlots.ID.mmMiddle3,
            GestureSlots.ID.mmDrag,
            GestureSlots.ID.tbLeft,
            GestureSlots.ID.tbRight,
            GestureSlots.ID.tbUp,
            GestureSlots.ID.tbDown,
        ]
    )

    static let all: [SannePreset] = [.standard, .minimal]

    static func named(_ id: String) -> SannePreset? {
        all.first { $0.id == id }
    }

    /// Fallback enablement when a slot has no `enabled` override.
    static func defaultEnabled(for slot: GestureSlots.Slot, presetId: String) -> Bool {
        if presetId == minimalId {
            return minimal.enabledSlotIds.contains(slot.id)
        }
        return GestureSlots.defaultEnabled(for: slot.legacyGate)
    }

    /// Same as `defaultEnabled(for:presetId:)` once the config is on slot enablement (v2).
    static func slotEnabled(_ slot: GestureSlots.Slot, config: SanneConfig) -> Bool {
        if config.version >= 2 {
            return defaultEnabled(for: slot, presetId: config.presetId)
        }
        return GestureSlots.legacyEnabled(slot.legacyGate, config: config)
    }

    static func hasActionRemaps(_ config: SanneConfig) -> Bool {
        if config.gestureOverrides.values.contains(where: { $0.effectiveActionId != nil }) {
            return true
        }
        for map in config.appGestureOverrides.values {
            if map.values.contains(where: { $0.effectiveActionId != nil }) { return true }
        }
        return false
    }

    /// The preset whose masters + slot enablement match `config`, or nil when the user has drifted (Custom).
    static func matching(_ config: SanneConfig) -> SannePreset? {
        all.first { $0.matches(config) }
    }

    func matches(_ config: SanneConfig) -> Bool {
        guard config.magicMouseTaps.enabled == masters.magicMouse,
              config.titlebarGestures.enabled == masters.titlebar,
              config.dockGestures.enabled == masters.dock,
              config.menubarGestures.enabled == masters.menubar,
              config.keyboard.enabled == masters.keyboard
        else { return false }

        for slot in GestureSlots.all {
            let want = enabledSlotIds.contains(slot.id)
            let live = BindingResolver.resolve(slotId: slot.id, config: config)?.enabled ?? false
            if live != want { return false }
        }
        return true
    }

    /// Writes masters + `presetId`. Clears per-slot `enabled` so the preset defaults take over.
    /// Action remaps stay unless `keepActionRemaps` is false.
    func apply(to config: inout SanneConfig, keepActionRemaps: Bool) {
        config.presetId = id
        if config.version < 2 { config.version = 2 }
        config.magicMouseTaps.enabled = masters.magicMouse
        config.titlebarGestures.enabled = masters.titlebar
        config.dockGestures.enabled = masters.dock
        config.menubarGestures.enabled = masters.menubar
        config.keyboard.enabled = masters.keyboard

        var next = config.gestureOverrides
        for (slotId, var entry) in next {
            entry.enabled = nil
            if !keepActionRemaps { entry.actionId = nil }
            if entry.isEmpty {
                next.removeValue(forKey: slotId)
            } else {
                next[slotId] = entry
            }
        }
        config.gestureOverrides = next
        if !keepActionRemaps {
            config.appGestureOverrides = [:]
        }
    }
}
