import Foundation

struct ResolvedGesture {
    let slotId: String
    let enabled: Bool
    let actionId: String
    let isModified: Bool
    let actionFixed: Bool
}

enum BindingResolver {
    /// Effective binding for a slot. Three layers, highest priority first:
    ///
    /// 1. `appGestureOverrides[frontmostBundleId]` — what the frontmost app asks for
    /// 2. `gestureOverrides` — the user's global remap
    /// 3. the slot's Sanne Standard default
    ///
    /// `frontmostBundleId` defaults to nil because every caller that wants the app-independent
    /// picture (device pages, All bindings, the cheat sheet) wants layer 1 skipped entirely.
    static func resolve(
        slotId: String,
        config: SanneConfig,
        frontmostBundleId: String? = nil
    ) -> ResolvedGesture? {
        guard let slot = GestureSlots.slot(id: slotId) else { return nil }

        let global = config.gestureOverrides[slotId]
        let app = frontmostBundleId.flatMap { config.appGestureOverrides[$0]?[slotId] }
        let override = app?.layered(over: global) ?? global ?? GestureOverrideEntry()

        let actionId = slot.actionFixed
            ? slot.defaultActionId
            : (override.effectiveActionId ?? slot.defaultActionId)
        PerfCounters.incBindingResolves()
        let enabled = override.enabled ?? SannePreset.slotEnabled(slot, config: config)
        let isModified = actionId != slot.defaultActionId || override.enabled != nil

        guard GestureSlots.masterEnabled(group: slot.group, config: config) else {
            return ResolvedGesture(
                slotId: slotId,
                enabled: false,
                actionId: slot.defaultActionId,
                isModified: isModified,
                actionFixed: slot.actionFixed
            )
        }

        return ResolvedGesture(
            slotId: slotId,
            enabled: enabled,
            actionId: actionId,
            isModified: isModified,
            actionFixed: slot.actionFixed
        )
    }

    static func isModified(slotId: String, config: SanneConfig, frontmostBundleId: String? = nil) -> Bool {
        resolve(slotId: slotId, config: config, frontmostBundleId: frontmostBundleId)?.isModified ?? false
    }

    static func modifiedCount(config: SanneConfig, frontmostBundleId: String? = nil) -> Int {
        GestureSlots.all
            .filter { isModified(slotId: $0.id, config: config, frontmostBundleId: frontmostBundleId) }
            .count
    }

    static func isCustomized(slotId: String, config: SanneConfig, scope: GestureBindingScope) -> Bool {
        switch scope {
        case .global:
            return isModified(slotId: slotId, config: config)
        case .app:
            return config.gestureOverride(slotId: slotId, scope: scope) != nil
        }
    }

    static func customizedCount(config: SanneConfig, scope: GestureBindingScope) -> Int {
        switch scope {
        case .global:
            return modifiedCount(config: config)
        case .app(let bundleId):
            return config.appGestureOverrides[bundleId]?.count ?? 0
        }
    }
}
