import AppKit
import SwiftUI

struct CheatSheetView: View {
    @ObservedObject private var store = ConfigStore.shared
    @State private var query = ""
    @State private var groupFilter: String?

    private var rows: [Row] {
        slotRows + extraRows
    }

    private var slotRows: [Row] {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return GestureSlots.all.map { slot in
            let resolved = BindingResolver.resolve(
                slotId: slot.id,
                config: store.config,
                frontmostBundleId: front
            )
            let actionId = resolved?.actionId ?? slot.defaultActionId
            return Row(
                id: slot.id,
                groupTitle: slot.group.rawValue,
                systemImage: GestureGlyph.systemImage(forGroup: slot.group),
                title: slot.title,
                actionTitle: ActionCatalog.title(for: actionId),
                enabled: resolved?.enabled ?? false,
                diagram: GestureDiagram.from(slotId: slot.id),
                editRoute: PreferencesRoute.route(for: slot.group),
                keywords: [slot.detail, slot.id, slot.group.rawValue, ActionCatalog.title(for: actionId)]
            )
        }
    }

    private var extraRows: [Row] {
        [
            Row(
                id: "extra.modifier-move",
                groupTitle: "Modifier + drag",
                systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                title: "⌥⌘ + drag",
                actionTitle: "Move window",
                enabled: store.config.modifierDrag.enabled && store.config.modifierDrag.moveEnabled,
                diagram: .trackpad(1, .drag),
                editRoute: PreferencesRoute.windows,
                keywords: ["option", "command", "move"]
            ),
            Row(
                id: "extra.modifier-resize",
                groupTitle: "Modifier + drag",
                systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                title: "⌃⌘ + drag",
                actionTitle: "Resize from nearest edge",
                enabled: store.config.modifierDrag.enabled && store.config.modifierDrag.resizeEnabled,
                diagram: .trackpad(1, .drag),
                editRoute: PreferencesRoute.windows,
                keywords: ["control", "command", "resize"]
            ),
            Row(
                id: "extra.restore",
                groupTitle: "Titlebar",
                systemImage: "rectangle.topthird.inset.filled",
                title: "Same snap twice",
                actionTitle: "Restore previous frame",
                enabled: store.config.titlebarGestures.enabled,
                diagram: .trackpad(2, .doubleTap, zone: .topEdge),
                editRoute: PreferencesRoute.windows,
                keywords: ["undo", "toggle", "restore"]
            ),
        ]
    }

    private var filtered: [Row] {
        rows.filter { row in
            if let groupFilter, row.groupTitle != groupFilter { return false }
            return row.matches(query)
        }
    }

    private var grouped: [(String, [Row])] {
        let order = GestureSlots.Group.allCases.map(\.rawValue) + ["Keyboard", "Modifier + drag"]
        return order.compactMap { title in
            let items = filtered.filter { $0.groupTitle == title }
            return items.isEmpty ? nil : (title, items)
        }
    }

    private var filterTitles: [String] {
        GestureSlots.Group.allCases.map(\.rawValue) + ["Keyboard", "Modifier + drag"]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search gestures…", text: $query)
                        .textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SanneFilterChip(title: "All", selected: groupFilter == nil) {
                            groupFilter = nil
                        }
                        ForEach(filterTitles, id: \.self) { title in
                            SanneFilterChip(title: title, selected: groupFilter == title) {
                                groupFilter = title
                            }
                        }
                    }
                }
            }
            .padding(14)

            Divider().opacity(0.6)

            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No matches")
                        .font(.headline)
                    Text("Try a different search or clear the filter.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.0) { title, items in
                        Section {
                            ForEach(items) { row in
                                HStack(alignment: .center, spacing: 12) {
                                    GestureDiagramView(diagram: row.diagram, size: 34, active: row.enabled)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.title)
                                            .font(.body.weight(.medium))
                                        Text(row.actionTitle)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    if let route = row.editRoute {
                                        Button("Edit in Settings") {
                                            PreferencesRoute.request(route)
                                            NotificationCenter.default.post(name: .sanneShowPreferences, object: nil)
                                        }
                                        .buttonStyle(.borderless)
                                        .font(.caption)
                                    }
                                }
                                .padding(.vertical, 3)
                                .opacity(row.enabled ? 1 : 0.45)
                            }
                        } header: {
                            Label(title, systemImage: items.first?.systemImage ?? "hand.draw")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 580, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    struct Row: Identifiable {
        let id: String
        let groupTitle: String
        let systemImage: String
        let title: String
        let actionTitle: String
        let enabled: Bool
        let diagram: GestureDiagram
        let editRoute: String?
        let keywords: [String]

        func matches(_ query: String) -> Bool {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            let hay = ([title, actionTitle, groupTitle] + keywords).joined(separator: " ").lowercased()
            return q.split(separator: " ").allSatisfy { hay.contains($0) }
        }
    }
}
