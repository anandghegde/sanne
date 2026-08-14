import AppKit
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

/// Gesture list with enable toggles, action remap, modified badge, and per-row reset.
/// Layout inspired by Multitouch.app: icon + title/subtitle rows in a clean list.
///
/// - Full catalog: Settings → All bindings (and the per-app sheet).
/// - Device/zone pages pass `fixedGroup` plus optional `header` sections (master switches,
///   tuning) so remaps live in the same scroll as the page settings. One List under a
///   fixed toolbar — a grouped Form here overflows the Settings window on macOS.
struct GestureEditorView<Header: View>: View {
    @EnvironmentObject private var store: ConfigStore

    /// Which binding layer this editor reads and writes. Defaults to `.global`; the per-app sheet
    /// passes `.app(bundleId:)`. Everything else goes through `resolved`, `isCustomized`, and
    /// `inherited`, so this is the only branch.
    var scope: GestureBindingScope = .global

    /// When set, only this group's slots appear; group filter chips and section headers are hidden
    /// (the parent page already names the device/zone).
    var fixedGroup: GestureSlots.Group? = nil
    /// Extra groups stacked after `fixedGroup` on the same page (Windows + Dock + Menubar).
    var extraGroups: [GestureSlots.Group] = []

    /// Sticky title above search on a device/zone page. The Form below starts at the settings.
    var pageTitle: String? = nil
    var pageSubtitle: String? = nil
    /// Dim the slot list when the matching device is unplugged.
    var dimSlots: Bool = false

    private let header: Header

    @State private var query = ""
    @State private var groupFilter: GestureSlots.Group?
    @State private var showModifiedOnly = false
    @State private var showAllGestures = false
    @State private var pickingSlotId: String?
    @State private var popoverSlotId: String?
    @State private var highlightedSlotId: String?

    init(
        scope: GestureBindingScope = .global,
        fixedGroup: GestureSlots.Group? = nil,
        extraGroups: [GestureSlots.Group] = [],
        pageTitle: String? = nil,
        pageSubtitle: String? = nil,
        dimSlots: Bool = false,
        @ViewBuilder header: () -> Header
    ) {
        self.scope = scope
        self.fixedGroup = fixedGroup
        self.extraGroups = extraGroups
        self.pageTitle = pageTitle
        self.pageSubtitle = pageSubtitle
        self.dimSlots = dimSlots
        self.header = header()
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.6)
            catalog
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    @ViewBuilder
    private var catalog: some View {
        if fixedGroup != nil {
            // List, not Form: grouped Form reports its full content height and the
            // window clips the page title. List takes the remaining pane and scrolls.
            ScrollViewReader { proxy in
                List {
                    header
                    slotRows
                }
                .listStyle(.inset)
                .frame(minHeight: 0)
                .onReceive(NotificationCenter.default.publisher(for: GestureActivity.highlightSlot)) { note in
                    revealAndHighlight(note.userInfo?["slotId"] as? String, proxy: proxy)
                }
            }
        } else if filteredSlots.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
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
                .frame(minHeight: 0)
                .onReceive(NotificationCenter.default.publisher(for: GestureActivity.highlightSlot)) { note in
                    revealAndHighlight(note.userInfo?["slotId"] as? String, proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    private var slotRows: some View {
        if filteredSlots.isEmpty {
            Section {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .listRowBackground(Color.clear)
            }
        } else if displayedGroups.count > 1 {
            ForEach(displayedGroups, id: \.self) { group in
                let slots = filteredSlots.filter { $0.group == group }
                if !slots.isEmpty {
                    Section(group.rawValue) {
                        ForEach(slots) { slot in
                            row(slot)
                        }
                    }
                }
            }
        } else {
            Section {
                ForEach(filteredSlots) { slot in
                    row(slot)
                }
            }
        }
    }

    private var displayedGroups: [GestureSlots.Group] {
        if let fixedGroup {
            return [fixedGroup] + extraGroups
        }
        return []
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
            if let pageTitle {
                SannePageHeader(title: pageTitle, subtitle: pageSubtitle)
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
            }

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
            .padding(.top, pageTitle == nil ? 12 : 2)

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
                    // Group chips only for the cross-cutting All bindings catalog.
                    if fixedGroup == nil {
                        ForEach(GestureSlots.Group.allCases) { g in
                            SanneFilterChip(title: g.rawValue, selected: groupFilter == g && !showModifiedOnly) {
                                groupFilter = g
                                showModifiedOnly = false
                            }
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
                let n = customizedCountInView
                if n > 0 {
                    Text("\(n) modified")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(modifiedBadgeTint)
                    Button(resetAllTitle) {
                        resetVisibleOverrides()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal, 14)

            if fixedGroup != nil, hiddenAdvancedCount > 0 || showAllGestures {
                Button {
                    showAllGestures.toggle()
                } label: {
                    Label(
                        showAllGestures
                            ? "Show fewer gestures"
                            : "Show all gestures (\(hiddenAdvancedCount))",
                        systemImage: showAllGestures ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }

            Color.clear.frame(height: 10)
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
            .accessibilityLabel("Enable \(slot.title)")

            GestureDiagramView(
                diagram: .from(slotId: slot.id),
                size: 36,
                active: enabled,
                label: slot.title
            )

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
                // Remappable rows put the action on the picker button. Fixed rows have no
                // picker, so the bound action stays here as the subtitle.
                if slot.actionFixed {
                    Text(ActionCatalog.title(for: actionId))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !slot.detail.isEmpty {
                    Text(slot.detail)
                        .font(.caption)
                        .foregroundStyle(slot.actionFixed ? .tertiary : .secondary)
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
                    popoverSlotId = slot.id
                } label: {
                    HStack(spacing: 4) {
                        Text(ActionCatalog.title(for: actionId))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .font(.callout)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Change action")
                .popover(isPresented: Binding(
                    get: { popoverSlotId == slot.id },
                    set: { if !$0 { popoverSlotId = nil } }
                ), arrowEdge: .bottom) {
                    ActionQuickMenu(
                        currentActionId: actionId,
                        onPick: { id in
                            setAction(slotId: slot.id, actionId: id)
                            popoverSlotId = nil
                        },
                        onMore: {
                            popoverSlotId = nil
                            pickingSlotId = slot.id
                        }
                    )
                }
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
        .opacity((enabled && !dimSlots) ? 1 : 0.5)
        .contentShape(Rectangle())
        .id(slot.id)
        .listRowBackground(
            highlightedSlotId == slot.id
                ? Color.accentColor.opacity(0.16)
                : Color.clear
        )
    }

    private func revealAndHighlight(_ slotId: String?, proxy: ScrollViewProxy) {
        guard let slotId, let slot = GestureSlots.slot(id: slotId) else { return }
        if !displayedGroups.isEmpty, !displayedGroups.contains(slot.group) { return }
        if slot.visibility == .advanced { showAllGestures = true }
        query = ""
        showModifiedOnly = false
        DispatchQueue.main.async {
            highlightedSlotId = slotId
            proxy.scrollTo(slotId, anchor: .center)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if highlightedSlotId == slotId { highlightedSlotId = nil }
        }
    }

    private var hiddenAdvancedCount: Int {
        GestureSlots.all.filter { slot in
            displayedGroups.contains(slot.group) && slot.visibility == .advanced
        }.count
    }

    private var filteredSlots: [GestureSlots.Slot] {
        GestureSlots.all.filter { slot in
            if !displayedGroups.isEmpty, !displayedGroups.contains(slot.group) { return false }
            if fixedGroup != nil, !showAllGestures, !showModifiedOnly, slot.visibility != .simple {
                return false
            }
            if showModifiedOnly {
                guard isCustomized(slot.id) else { return false }
            } else if fixedGroup == nil, let groupFilter, slot.group != groupFilter {
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

    /// Modified count for the badge / reset affordance: scoped to `fixedGroup` when embedded.
    private var customizedCountInView: Int {
        let slots: [GestureSlots.Slot]
        if !displayedGroups.isEmpty {
            slots = GestureSlots.all.filter { displayedGroups.contains($0.group) }
        } else {
            slots = GestureSlots.all
        }
        return slots.filter { isCustomized($0.id) }.count
    }

    private func resetVisibleOverrides() {
        store.update { cfg in
            if !displayedGroups.isEmpty {
                for slot in GestureSlots.all where displayedGroups.contains(slot.group) {
                    cfg.clearGestureOverride(slotId: slot.id, scope: scope)
                }
            } else {
                cfg.clearAllGestureOverrides(scope: scope)
            }
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
            if fixedGroup != nil {
                return "Enable a gesture and change its action. Master switches for this section still apply."
            }
            return "Search every gesture. Day-to-day remaps live under Magic Mouse, Trackpad, Windows, Dock, and Menubar."
        case .app(let bundleId):
            let name = ActionCatalog.appDisplayName(bundleId: bundleId)
            // The last clause is the one surprise in this sheet: recognition is gated globally, so
            // enabling a gesture here has an effect outside this app.
            return "Applies only while \(name) is frontmost. Untouched rows follow your global bindings; enabling one also turns its section on globally."
        }
    }

    private var resetAllTitle: String {
        switch scope {
        case .global:
            return fixedGroup != nil ? "Reset these remaps" : "Reset all remaps"
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
        let standardEnabled = SannePreset.slotEnabled(slot, config: config)
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

extension GestureEditorView where Header == EmptyView {
    init(
        scope: GestureBindingScope = .global,
        fixedGroup: GestureSlots.Group? = nil,
        extraGroups: [GestureSlots.Group] = [],
        pageTitle: String? = nil,
        pageSubtitle: String? = nil,
        dimSlots: Bool = false
    ) {
        self.init(
            scope: scope,
            fixedGroup: fixedGroup,
            extraGroups: extraGroups,
            pageTitle: pageTitle,
            pageSubtitle: pageSubtitle,
            dimSlots: dimSlots
        ) { EmptyView() }
    }
}

private struct SlotPickIdent: Identifiable {
    let id: String
}

private struct ActionQuickMenu: View {
    let currentActionId: String
    let onPick: (String) -> Void
    let onMore: () -> Void

    private static let common: [String] = [
        ActionCatalog.ID.none,
        ActionCatalog.ID.clickLeft,
        ActionCatalog.ID.clickRight,
        ActionCatalog.ID.clickMiddle,
        ActionCatalog.ID.snapLeftHalf,
        ActionCatalog.ID.snapRightHalf,
        ActionCatalog.ID.snapMaximize,
        ActionCatalog.ID.minimize,
        ActionCatalog.ID.close,
        ActionCatalog.ID.fullscreen,
        ActionCatalog.ID.missionControl,
        ActionCatalog.ID.appExpose,
        ActionCatalog.ID.browserPrevTab,
        ActionCatalog.ID.browserNextTab,
        ActionCatalog.ID.browserBack,
        ActionCatalog.ID.browserForward,
        ActionCatalog.ID.restore,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.common, id: \.self) { id in
                Button {
                    onPick(id)
                } label: {
                    HStack {
                        Text(ActionCatalog.title(for: id))
                        Spacer()
                        if id == currentActionId {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider().padding(.vertical, 4)
            Button("More…", action: onMore)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .padding(.vertical, 6)
        .frame(minWidth: 220)
    }
}
