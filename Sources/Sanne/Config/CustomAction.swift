import Foundation

/// A user-defined action that runs a script instead of one of the built-in catalog actions.
///
/// Bindings refer to these by `ActionCatalog.customActionId(_:)` (`action.custom.<uuid>`) rather
/// than by name, so renaming an action keeps every gesture pointed at it.
struct CustomActionDef: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        /// `payload` is a shell script, run through `zsh -c` (no login profile).
        case shell
        /// `payload` is AppleScript source, run through `osascript -e` so it shares the same
        /// timeout and error logging as the other kinds.
        case appleScript
        /// `payload` is the name of a macOS Shortcuts shortcut, run via `shortcuts run`.
        case shortcut

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .shell: return "Shell script"
            case .appleScript: return "AppleScript"
            case .shortcut: return "Shortcut"
            }
        }
    }

    var id: UUID
    var name: String
    var kind: Kind
    /// Script source for `.shell` / `.appleScript`, shortcut name for `.shortcut`.
    var payload: String

    init(id: UUID = UUID(), name: String = "", kind: Kind = .shell, payload: String = "") {
        self.id = id
        self.name = name
        self.kind = kind
        self.payload = payload
    }

    /// Tolerant decode in the same spirit as the other config models: a config written by a newer
    /// Sanne (or hand-edited) must not fail the whole load, so unknown kinds degrade to `.shell`
    /// and missing fields fall back to empty rather than throwing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .shell
        payload = try c.decodeIfPresent(String.self, forKey: .payload) ?? ""
    }

    /// Name shown in the picker / cheat sheet; unnamed defs still need something clickable.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.displayName : trimmed
    }

    /// False for defs the user started but never filled in — running them would be a no-op.
    var isRunnable: Bool {
        !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension SanneConfig {
    func customAction(id: UUID) -> CustomActionDef? {
        customActions.first { $0.id == id }
    }

    /// Insert or replace by id, so the editor can save new and existing defs through one path.
    mutating func upsertCustomAction(_ def: CustomActionDef) {
        if let idx = customActions.firstIndex(where: { $0.id == def.id }) {
            customActions[idx] = def
        } else {
            customActions.append(def)
        }
    }

    /// Removes the def and any gesture override still pointing at it, so a deleted action can't
    /// leave slots bound to a dangling `action.custom.<uuid>` id.
    ///
    /// Clears both the global map and every app layer — a per-app remap to a deleted script would
    /// otherwise keep resolving as "Missing action" with no path short of hand-editing the JSON.
    mutating func removeCustomAction(id: UUID) {
        customActions.removeAll { $0.id == id }
        let deadId = ActionCatalog.customActionId(id)
        clearDeadCustomActionReferences(deadId, in: &gestureOverrides)
        for bundleId in appGestureOverrides.keys {
            var map = appGestureOverrides[bundleId] ?? [:]
            clearDeadCustomActionReferences(deadId, in: &map)
            if map.isEmpty {
                appGestureOverrides.removeValue(forKey: bundleId)
            } else {
                appGestureOverrides[bundleId] = map
            }
        }
    }

    /// Drops or blanks any entry in `map` whose `actionId` is `deadId`.
    private func clearDeadCustomActionReferences(
        _ deadId: String,
        in map: inout [String: GestureOverrideEntry]
    ) {
        let staleSlots = map.filter { $0.value.actionId == deadId }.map(\.key)
        for slotId in staleSlots {
            var entry = map[slotId] ?? GestureOverrideEntry()
            entry.actionId = nil
            if entry.isEmpty {
                map.removeValue(forKey: slotId)
            } else {
                map[slotId] = entry
            }
        }
    }
}
