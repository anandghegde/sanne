import AppKit
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

/// Full gesture list with enable toggles, action remap, modified badge, and per-row reset.
/// Layout inspired by Multitouch.app: icon + title/subtitle rows in a clean list.
struct GestureEditorView: View {
    @EnvironmentObject private var store: ConfigStore

    /// Which binding layer this editor reads and writes. Defaults to `.global` so Settings →
    /// Gestures is unchanged; the per-app sheet passes `.app(bundleId:)`. Everything else in the
    /// view goes through `resolved`, `isCustomized` and `inherited`, so this is the only branch.
    var scope: GestureBindingScope = .global

    @State private var query = ""
    @State private var groupFilter: GestureSlots.Group?
    @State private var showModifiedOnly = false
    @State private var pickingSlotId: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.6)
            if filteredSlots.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(grouped, id: \.0) { group, slots in
                        Section {
                            ForEach(slots) { slot in
                                row(slot)
                            }
                        } header: {
                            Label(group.rawValue, systemImage: GestureGlyph.systemImage(forGroup: group))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: Binding(
            get: { pickingSlotId.map { SlotPickIdent(id: $0) } },
            set: { pickingSlotId = $0?.id }
        )) { ident in
            if let slot = GestureSlots.slot(id: ident.id) {
                // Both closures spelled out rather than trailing: they have identical signatures,
                // so positional syntax would let a future reordering silently swap pick and cancel.
                ActionPickerSheet(
                    store: store,
                    slot: slot,
                    currentActionId: resolved(slot)?.actionId ?? slot.defaultActionId,
                    onPick: { actionId in
                        setAction(slotId: slot.id, actionId: actionId)
                        pickingSlotId = nil
                    },
                    onCancel: {
                        pickingSlotId = nil
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("No gestures match")
                .font(.headline)
            Text("Clear search or filters.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
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
            .padding(.horizontal, 14)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SanneFilterChip(title: "All", selected: groupFilter == nil && !showModifiedOnly) {
                        groupFilter = nil
                        showModifiedOnly = false
                    }
                    SanneFilterChip(title: "Modified", selected: showModifiedOnly) {
                        showModifiedOnly = true
                        groupFilter = nil
                    }
                    ForEach(GestureSlots.Group.allCases) { g in
                        SanneFilterChip(title: g.rawValue, selected: groupFilter == g && !showModifiedOnly) {
                            groupFilter = g
                            showModifiedOnly = false
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(scopeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                let n = BindingResolver.customizedCount(config: store.config, scope: scope)
                if n > 0 {
                    Text("\(n) modified")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(modifiedBadgeTint)
                    Button(resetAllTitle) {
                        store.update { $0.clearAllGestureOverrides(scope: scope) }
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
    }

    private func row(_ slot: GestureSlots.Slot) -> some View {
        let effective = resolved(slot)
        let enabled = effective?.enabled ?? false
        let actionId = effective?.actionId ?? slot.defaultActionId
        // Badge and Reset track what *this* scope changed, so the app sheet doesn't mark — or offer
        // to reset — rows the user only customised globally.
        let modified = isCustomized(slot.id)

        return HStack(alignment: .center, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { setEnabled(slotId: slot.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            GestureDiagramView(diagram: .from(slotId: slot.id), size: 36, active: enabled)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(slot.title)
                        .font(.body.weight(.medium))
                    if modified {
                        badge(modifiedBadgeTitle, tint: modifiedBadgeTint)
                    } else if isInheritedRemap(slot) {
                        // Grey, not orange: nothing here is this app's doing, it is just not the
                        // Sanne Standard default either.
                        badge("From global", tint: .gray)
                    }
                }
                Text(ActionCatalog.title(for: actionId))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !slot.detail.isEmpty {
                    Text(slot.detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if slot.actionFixed {
                Text("Fixed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Button {
                    pickingSlotId = slot.id
                } label: {
                    HStack(spacing: 4) {
                        Text("Action")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(.callout)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .help(ActionCatalog.title(for: actionId))
            }

            Button("Reset") {
                store.update { $0.clearGestureOverride(slotId: slot.id, scope: scope) }
            }
            .buttonStyle(.borderless)
            .disabled(!modified)
            .font(.caption)
            .opacity(modified ? 1 : 0.35)
        }
        .padding(.vertical, 5)
        .opacity(enabled ? 1 : 0.5)
        .contentShape(Rectangle())
    }

    private var filteredSlots: [GestureSlots.Slot] {
        GestureSlots.all.filter { slot in
            if showModifiedOnly {
                guard isCustomized(slot.id) else { return false }
            } else if let groupFilter, slot.group != groupFilter {
                return false
            }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            let hay = [slot.title, slot.detail, slot.id, slot.group.rawValue, slot.defaultActionTitle]
                .joined(separator: " ")
                .lowercased()
            return q.split(separator: " ").allSatisfy { hay.contains($0) }
        }
    }

    private var grouped: [(GestureSlots.Group, [GestureSlots.Slot])] {
        GestureSlots.Group.allCases.compactMap { g in
            let items = filteredSlots.filter { $0.group == g }
            return items.isEmpty ? nil : (g, items)
        }
    }

    // MARK: - Scope

    /// Effective binding as this editor should present it: the app sheet previews what will happen
    /// while that app is frontmost, the global tab shows the app-independent result.
    private func resolved(_ slot: GestureSlots.Slot) -> ResolvedGesture? {
        BindingResolver.resolve(slotId: slot.id, config: store.config, frontmostBundleId: scope.bundleId)
    }

    private func isCustomized(_ slotId: String) -> Bool {
        BindingResolver.isCustomized(slotId: slotId, config: store.config, scope: scope)
    }

    /// Capsule tag beside a row title. One tint drives both fill and text so every badge reads as the
    /// same component, and the global tab's orange "Modified" keeps the exact look it always had.
    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }

    /// "Modified" is ambiguous in the app sheet, where the interesting distinction is whether the
    /// change belongs to this app or was inherited.
    private var modifiedBadgeTitle: String {
        switch scope {
        case .global: return "Modified"
        case .app: return "This app"
        }
    }

    /// One tint per layer, so which layer a row belongs to is legible without reading the badge:
    /// orange for your global remaps, blue for this app's, grey for anything merely inherited.
    private var modifiedBadgeTint: Color {
        switch scope {
        case .global: return .orange
        case .app: return .blue
        }
    }

    private var scopeHint: String {
        switch scope {
        case .global:
            return "Change any default action. Section toggles still apply as master switches."
        case .app(let bundleId):
            let name = ActionCatalog.appDisplayName(bundleId: bundleId)
            // The last clause is the one surprise in this sheet: recognition is gated globally, so
            // enabling a gesture here has an effect outside this app.
            return "Applies only while \(name) is frontmost. Untouched rows follow your global bindings; enabling one also turns its section on globally."
        }
    }

    private var resetAllTitle: String {
        switch scope {
        case .global: return "Reset all remaps"
        case .app: return "Reset this app"
        }
    }

    /// What the slot would do if this scope said nothing: Sanne Standard plus its section toggle for
    /// `.global`, the user's global binding for `.app`.
    ///
    /// Writing exactly this value stores nothing instead of a redundant entry, which is what keeps
    /// "modified" meaning "differs from the layer below" in both editors.
    ///
    /// The `.app` case reads the global layer directly rather than through `BindingResolver`, which
    /// reports `enabled: false` for every slot whose group master toggle is off. Comparing against
    /// that would make switching a row off in the app sheet look like "same as inherited" and store
    /// nothing — quietly discarding the user's choice the moment the master came back on.
    private func inherited(_ slot: GestureSlots.Slot, config: SanneConfig) -> (enabled: Bool, actionId: String) {
        let standardEnabled = GestureSlots.legacyEnabled(slot.legacyGate, config: config)
        switch scope {
        case .global:
            return (standardEnabled, slot.defaultActionId)
        case .app:
            let global = config.gestureOverride(slotId: slot.id, scope: .global)
            return (
                global?.enabled ?? standardEnabled,
                slot.actionFixed ? slot.defaultActionId : (global?.effectiveActionId ?? slot.defaultActionId)
            )
        }
    }

    /// True when this row's binding comes from the user's global remap and the app leaves it alone.
    ///
    /// Without this the app sheet renders an inherited remap identically to a Sanne Standard row, and
    /// the three layers the feature is built on become indistinguishable at a glance.
    ///
    /// Asks the global layer the same presence question `modified` asks of this one, rather than
    /// reading `isModified` off the resolved gesture: pruning guarantees that a stored entry means a
    /// real customisation, so this answer cannot drift with how the resolver merges layers.
    private func isInheritedRemap(_ slot: GestureSlots.Slot) -> Bool {
        guard case .app = scope, !isCustomized(slot.id) else { return false }
        return BindingResolver.isCustomized(slotId: slot.id, config: store.config, scope: .global)
    }

    // MARK: - Mutation

    private func setEnabled(slotId: String, enabled: Bool) {
        store.update { cfg in
            guard let slot = GestureSlots.slot(id: slotId) else { return }
            var entry = cfg.gestureOverride(slotId: slotId, scope: scope) ?? GestureOverrideEntry()
            entry.enabled = enabled == inherited(slot, config: cfg).enabled ? nil : enabled
            cfg.setGestureOverride(slotId: slotId, entry: entry, scope: scope)
            if enabled {
                cfg.enableLegacyGate(slotId: slotId)
            }
        }
    }

    private func setAction(slotId: String, actionId: String) {
        store.update { cfg in
            guard let slot = GestureSlots.slot(id: slotId), !slot.actionFixed else { return }
            var entry = cfg.gestureOverride(slotId: slotId, scope: scope) ?? GestureOverrideEntry()
            entry.actionId = actionId == inherited(slot, config: cfg).actionId ? nil : actionId
            cfg.setGestureOverride(slotId: slotId, entry: entry, scope: scope)
            cfg.enableLegacyGate(slotId: slotId)
        }
    }
}

private struct SlotPickIdent: Identifiable {
    let id: String
}

// MARK: - Action picker sheet

private struct ActionPickerSheet: View {
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
                        // Creating a script from this picker is only ever in service of binding it,
                        // so skip the extra trip through the list. Editing an existing one is a
                        // separate intent and must not silently rebind the gesture.
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

    // MARK: - Scripts

    /// Rendered from the observed store rather than from `ActionCatalog.grouped`, whose script
    /// entries come from a lock-protected mirror SwiftUI can't observe — the list would then go
    /// stale after a save or delete. `.script` is filtered out of `builtInSections` so the two
    /// sources can't produce duplicate rows.
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

    /// The picking button and the edit / delete buttons are siblings in one `HStack`, never nested:
    /// a button inside a button has ambiguous hit-testing, and tapping “edit” would also fire the
    /// row's own pick action.
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

// MARK: - Keystroke recorder

private struct KeystrokeRecorderSheet: View {
    let onRecord: (CGKeyCode, CGEventFlags) -> Void
    let onCancel: () -> Void

    @State private var preview = "Press a key combination…"
    @State private var captured: (CGKeyCode, CGEventFlags)?
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Record keystroke")
                    .font(.headline)
                Text("Hold modifiers, then press a key. Escape cancels.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(preview)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(captured == nil ? 0.35 : 0.8), lineWidth: 1.5)
                )

            HStack {
                Button("Cancel", action: finishCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Use keystroke") {
                    if let c = captured {
                        stopMonitor()
                        onRecord(c.0, c.1)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(captured == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear(perform: startMonitor)
        .onDisappear(perform: stopMonitor)
    }

    private func startMonitor() {
        stopMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape with no capture → cancel; with capture → clear and keep listening
            if event.keyCode == 53 {
                if captured != nil {
                    captured = nil
                    preview = "Press a key combination…"
                    return nil
                }
                finishCancel()
                return nil
            }
            if ActionCatalog.isModifierKeyCode(event.keyCode) {
                return nil
            }
            let flags = ActionCatalog.cgFlags(from: event.modifierFlags)
            let key = CGKeyCode(event.keyCode)
            captured = (key, flags)
            preview = ActionCatalog.formatKeystroke(keyCode: key, flags: flags)
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func finishCancel() {
        stopMonitor()
        onCancel()
    }
}
