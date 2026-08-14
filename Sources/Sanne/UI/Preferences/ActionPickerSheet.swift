import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ActionPickerSheet: View {
    /// Observed so the Scripts section refreshes the moment a script is saved or deleted; the
    /// catalog's own copy of the defs lives behind a lock that SwiftUI cannot observe.
    @ObservedObject var store: ConfigStore
    let slot: GestureSlots.Slot
    let currentActionId: String
    let onPick: (String) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var activeSheet: Modal?
    @State private var deleting: CustomActionDef?

    /// One presentation slot for both child sheets: stacking two `.sheet` modifiers on the same
    /// view is unreliable, and a script can be created from the keystroke recorder's own row.
    private enum Modal: Identifiable, Equatable {
        case keystroke
        case script(def: CustomActionDef, isNew: Bool)

        var id: String {
            switch self {
            case .keystroke: return "keystroke"
            case .script(let def, _): return def.id.uuidString
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose action")
                        .font(.headline)
                    Text(slot.title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            HStack(spacing: 8) {
                Button {
                    activeSheet = .keystroke
                } label: {
                    Label("Record keystroke", systemImage: "keyboard")
                }
                .buttonStyle(.bordered)

                Button {
                    pickApplication()
                } label: {
                    Label("Open app…", systemImage: "app.badge")
                }
                .buttonStyle(.bordered)

                Button {
                    activeSheet = .script(def: CustomActionDef(), isNew: true)
                } label: {
                    Label("New script…", systemImage: "terminal")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter actions…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            List {
                scriptsSection

                ForEach(builtInSections, id: \.0) { cat, actions in
                    Section(cat.rawValue) {
                        ForEach(actions) { action in
                            Button {
                                onPick(action.id)
                            } label: {
                                HStack(spacing: 12) {
                                    SanneIconBadge(
                                        systemImage: glyph(for: action),
                                        selected: action.id == currentActionId,
                                        size: 26
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if action.id == slot.defaultActionId {
                                            Text("Sanne Standard default")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else if ActionCatalog.isDynamicAction(action.id) {
                                            Text("Custom")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if action.id == currentActionId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 460, height: 540)
        .sheet(item: $activeSheet) { modal in
            switch modal {
            case .keystroke:
                KeystrokeRecorderSheet(
                    onRecord: { keyCode, flags in
                        let id = ActionCatalog.customKeystrokeId(keyCode: keyCode, flags: flags)
                        activeSheet = nil
                        onPick(id)
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            case .script(let def, let isNew):
                CustomActionSheet(
                    initial: def,
                    onSave: { saved in
                        store.update { $0.upsertCustomAction(saved) }
                        activeSheet = nil
                        if isNew {
                            onPick(ActionCatalog.customActionId(saved.id))
                        }
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete “\(deleting?.displayName ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let def = deleting {
                    store.update { $0.removeCustomAction(id: def.id) }
                }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Any gesture using this script goes back to its Sanne Standard default.")
        }
    }

    private var scripts: [CustomActionDef] {
        store.config.customActions.filter { ActionCatalog.matches(ActionCatalog.action(for: $0), query: query) }
    }

    private var builtInSections: [(ActionCatalog.Category, [ActionCatalog.Action])] {
        ActionCatalog.grouped(filter: query, includingDynamic: currentActionId)
            .filter { $0.0 != .script }
    }

    @ViewBuilder
    private var scriptsSection: some View {
        if !scripts.isEmpty {
            Section(ActionCatalog.Category.script.rawValue) {
                ForEach(scripts) { def in
                    scriptRow(def)
                }
            }
        }
    }

    private func scriptRow(_ def: CustomActionDef) -> some View {
        let actionId = ActionCatalog.customActionId(def.id)
        return HStack(spacing: 8) {
            Button {
                onPick(actionId)
            } label: {
                HStack(spacing: 12) {
                    SanneIconBadge(
                        systemImage: def.kind.glyph,
                        selected: actionId == currentActionId,
                        size: 26
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(def.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(def.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                activeSheet = .script(def: def, isNew: false)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit this script")

            Button {
                deleting = def
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this script")
        }
        .padding(.vertical, 3)
    }

    private func glyph(for action: ActionCatalog.Action) -> String {
        if ActionCatalog.parseLaunchApp(action.id) != nil { return "app.fill" }
        if ActionCatalog.parseCustomKeystroke(action.id) != nil { return "keyboard" }
        switch action.category {
        case .window: return "rectangle.split.2x1"
        case .clicks: return "cursorarrow.click"
        case .system: return "macwindow.on.rectangle"
        case .dock: return "dock.rectangle"
        case .menubar: return "menubar.rectangle"
        case .browser: return "safari"
        case .keyboard: return "keyboard"
        case .apps: return "app.fill"
        case .script: return "terminal"
        case .special: return "sparkles"
        }
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an application to open when this gesture fires."
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let bid = bundle.bundleIdentifier, !bid.isEmpty else {
            Log.warn(.config, "Open app picker: no bundle id for \(url.path)")
            return
        }
        onPick(ActionCatalog.launchAppId(bundleId: bid))
    }
}
