import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    private enum Tab: String, CaseIterable, Identifiable, Hashable {
        case general = "Home"
        case magicMouse = "Magic Mouse"
        case trackpad = "Trackpad"
        case windows = "Windows"
        case keyboard = "Keyboard"
        case apps = "Apps"
        case dock = "Dock"
        case menubar = "Menubar"
        /// Cross-cutting catalog; day-to-day remaps live on each device/zone page.
        case allBindings = "All bindings"
        case debug = "Debug Log"
        case about = "About"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: return "house.fill"
            case .magicMouse: return "computermouse.fill"
            case .trackpad: return "rectangle.and.hand.point.up.left.fill"
            case .windows: return "macwindow"
            case .keyboard: return "keyboard.fill"
            case .apps: return "app.badge.fill"
            case .dock: return "dock.rectangle"
            case .menubar: return "menubar.rectangle"
            case .allBindings: return "list.bullet.rectangle"
            case .debug: return "text.alignleft"
            case .about: return "info.circle.fill"
            }
        }

        /// System Settings-style tint for the sidebar icon well.
        var tint: Color {
            switch self {
            case .general: return .blue
            case .magicMouse: return .pink
            case .trackpad: return .mint
            case .windows: return .indigo
            case .keyboard: return .gray
            case .apps: return .orange
            case .dock: return .teal
            case .menubar: return .cyan
            case .allBindings: return .purple
            case .debug: return .brown
            case .about: return .blue
            }
        }
    }

    @State private var tab: Tab? = .general
    @State private var importExportMessage: String?

    var body: some View {
        // Manual sidebar, not NavigationSplitView. A split view + grouped Form in an
        // NSHostingController window reports the Form's full content height, then the
        // window clips the sidebar, page title, and top rows (and the Form will not scroll).
        HStack(spacing: 0) {
            List(Tab.allCases, selection: $tab) { t in
                Label {
                    Text(t.rawValue)
                } icon: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(t.tint.gradient)
                        Image(systemName: t.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 21, height: 21)
                    .shadow(color: t.tint.opacity(0.35), radius: 1.5, y: 0.5)
                }
                .tag(t)
            }
            .listStyle(.sidebar)
            .frame(width: SanneChrome.sidebarWidth)

            Divider()

            Group {
                switch tab ?? .general {
                case .general: general
                case .magicMouse: magicMouse
                case .trackpad: trackpad
                case .windows: windows
                case .keyboard: detailScroll { keyboard }
                case .apps: detailScroll { apps }
                case .dock: dock
                case .menubar: menubar
                case .allBindings: GestureEditorView()
                case .debug: DebugLogView()
                case .about: detailScroll { about }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 500)
    }

    @ViewBuilder
    private func detailScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    // MARK: - Home

    private var general: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SannePageHeader(
                    title: "Home",
                    subtitle: "Status, quick toggles, and shortcuts. Everything stays on this Mac."
                )

                statusCard

                if !app.conflicts.isEmpty {
                    conflictBanner
                }

                Form {
                    Section {
                        Toggle("Pause all gestures", isOn: Binding(
                            get: { store.config.paused },
                            set: { v in store.update { $0.paused = v } }
                        ))
                        Toggle("Launch at login", isOn: Binding(
                            get: { store.config.launchAtLogin },
                            set: { v in app.setLaunchAtLogin(v) }
                        ))
                        if store.config.launchAtLogin, !LaunchAtLogin.isBundledApp {
                            Text("Package as Sanne.app for login items to register (scripts/package-app.sh). Preference is saved.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if LaunchAtLogin.status == .requiresApproval {
                            Text("macOS needs approval: System Settings → General → Login Items.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Toggle("Haptic feedback", isOn: Binding(
                            get: { store.config.window.haptics },
                            set: { v in store.update { $0.window.haptics = v } }
                        ))
                        Toggle("Snap preview overlay", isOn: Binding(
                            get: { store.config.window.showPreview },
                            set: { v in store.update { $0.window.showPreview = v } }
                        ))
                        Toggle("Action name overlay", isOn: Binding(
                            get: { store.config.hud.enabled },
                            set: { v in store.update { $0.hud.enabled = v } }
                        ))
                        .help("A brief label near the bottom of the screen naming the action a gesture just fired. Clicks and drags stay silent.")
                    } header: {
                        Text("Global")
                    }

                    Section {
                        Toggle("Magic Mouse taps", isOn: Binding(
                            get: { store.config.magicMouseTaps.enabled },
                            set: { v in store.update { $0.magicMouseTaps.enabled = v } }
                        ))
                        Toggle("Titlebar window gestures", isOn: Binding(
                            get: { store.config.titlebarGestures.enabled },
                            set: { v in store.update { $0.titlebarGestures.enabled = v } }
                        ))
                        Toggle("Dock gestures", isOn: Binding(
                            get: { store.config.dockGestures.enabled },
                            set: { v in store.update { $0.dockGestures.enabled = v } }
                        ))
                        Toggle("Menubar gestures", isOn: Binding(
                            get: { store.config.menubarGestures.enabled },
                            set: { v in store.update { $0.menubarGestures.enabled = v } }
                        ))
                    } header: {
                        Text("Quick toggles")
                    }

                    Section {
                        HStack(spacing: 10) {
                            Button {
                                NotificationCenter.default.post(name: .sanneShowTutorial, object: nil)
                            } label: {
                                Label("Tutorial", systemImage: "graduationcap")
                            }
                            Button {
                                NotificationCenter.default.post(name: .sanneShowCheatSheet, object: nil)
                            } label: {
                                Label("Cheat Sheet", systemImage: "list.bullet.rectangle")
                            }
                        }
                        let modified = BindingResolver.modifiedCount(config: store.config)
                        if modified > 0 {
                            Text("\(modified) gesture\(modified == 1 ? "" : "s") remapped — edit on Magic Mouse, Trackpad, Windows, Dock, or Menubar (or All bindings)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Help")
                    }

                    Section {
                        HStack(spacing: 10) {
                            Button("Export config…") { exportConfig() }
                            Button("Import config…") { importConfig() }
                        }
                        if let importExportMessage {
                            Text(importExportMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Backup")
                    }

                    Section {
                        Button("Reset to Sanne Standard", role: .destructive) {
                            store.resetToStandard()
                            importExportMessage = "Reset to Sanne Standard."
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 680)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sanne")
                        .font(.title3.weight(.semibold))
                    Text(statusSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                SanneStatusPill(
                    title: app.isPaused ? "Paused" : (app.multitouchRunning ? "Running" : "Idle"),
                    kind: app.isPaused ? .warning : (app.multitouchRunning ? .ok : .neutral)
                )
                SanneStatusPill(
                    title: app.accessibilityTrusted ? "Accessibility" : "Needs Accessibility",
                    kind: app.accessibilityTrusted ? .ok : .error
                )
                if let err = app.multitouchError {
                    SanneStatusPill(title: "Multitouch error", kind: .error)
                        .help(err)
                } else {
                    SanneStatusPill(
                        title: app.multitouchRunning ? "Multitouch active" : "Multitouch inactive",
                        kind: app.multitouchRunning ? .ok : .warning
                    )
                }
            }

            if !app.accessibilityTrusted {
                HStack(spacing: 10) {
                    Button("Grant…") { app.requestAccessibility() }
                        .keyboardShortcut(.defaultAction)
                    Button("Open Settings") { Permissions.openAccessibilitySettings() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 680, alignment: .leading)
        .background(SanneChrome.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SanneChrome.subtleBorder, lineWidth: 1)
        )
    }

    private var conflictBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Also running: \(app.conflicts.joined(separator: ", ")). Consider pausing other gesture apps.")
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusSummary: String {
        if !app.accessibilityTrusted { return "Grant Accessibility to move windows and recognize gestures." }
        if app.isPaused { return "All gestures are paused." }
        if app.isEffectivelyPaused {
            let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "this app"
            return "Paused for \(name) via app override."
        }
        if app.multitouchRunning { return "Gestures are active." }
        return "Waiting for multitouch devices…"
    }

    // MARK: - Sections

    /// Device/zone pages: master switches + tuning share one scroll with the remappable slots.
    /// GestureEditorView owns that scroll (List under a fixed toolbar). Do not wrap this
    /// in another Form or ScrollView — two scroll views fight for height on macOS.
    private func deviceZonePage<Top: View>(
        group: GestureSlots.Group,
        title: String,
        subtitle: String,
        @ViewBuilder top: () -> Top
    ) -> some View {
        GestureEditorView(
            fixedGroup: group,
            pageTitle: title,
            pageSubtitle: subtitle,
            header: top
        )
    }

    private var magicMouse: some View {
        deviceZonePage(
            group: .magicMouse,
            title: "Magic Mouse",
            subtitle: "Silent taps and multi-finger actions. Enable each gesture and change its action below."
        ) {
            Section {
                Toggle("Enable Magic Mouse taps", isOn: Binding(
                    get: { store.config.magicMouseTaps.enabled },
                    set: { v in store.update { $0.magicMouseTaps.enabled = v } }
                ))
                Text("Master switch for all Magic Mouse gestures. Works best with a Magic Mouse.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // multiClick has no remappable slot — multi-tap is still multi-click, not an action.
            Section("Options") {
                GestureToggleRow(
                    diagram: .mouse(1, .doubleTap),
                    title: "Double / triple tap → multi-click",
                    subtitle: "Double-tap renames files / selects words; triple selects a line or paragraph.",
                    isOn: bindMM(\.multiClick)
                )
            }

            Section("Tuning") {
                Stepper(value: Binding(
                    get: { store.config.magicMouseTaps.sensitivity },
                    set: { v in store.update { $0.magicMouseTaps.sensitivity = max(-2, min(2, v)) } }
                ), in: -2...2) {
                    Text("Tap sensitivity: \(store.config.magicMouseTaps.sensitivity)")
                }
                Text("−2 = stricter (fewer scroll false-clicks). +2 = more taps accepted. Default 0 is a good balance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { store.config.magicMouseTaps.leftRightSplit },
                    set: { v in store.update { $0.magicMouseTaps.leftRightSplit = v } }
                ), in: 0.3...0.7) {
                    Text("Left / right split")
                }
                Text("Left / right split: \(String(format: "%.0f%%", store.config.magicMouseTaps.leftRightSplit * 100))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { store.config.magicMouseTaps.deadZone },
                    set: { v in store.update { $0.magicMouseTaps.deadZone = v } }
                ), in: 0...0.2) {
                    Text("Dead zone")
                }
                Text("Dead zone: \(String(format: "%.0f%%", store.config.magicMouseTaps.deadZone * 100))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var windows: some View {
        deviceZonePage(
            group: .titlebar,
            title: "Windows",
            subtitle: "Two fingers on a title bar to snap, maximize, minimize, or close. Remap each gesture below."
        ) {
            Section {
                Toggle("Titlebar window gestures", isOn: Binding(
                    get: { store.config.titlebarGestures.enabled },
                    set: { v in store.update { $0.titlebarGestures.enabled = v } }
                ))
                windowGestureMap
                    .padding(.vertical, 4)
            }

            Section("Modifier + drag") {
                Toggle("Enable modifier drag", isOn: Binding(
                    get: { store.config.modifierDrag.enabled },
                    set: { v in store.update { $0.modifierDrag.enabled = v } }
                ))
                Toggle("⌥⌘ + drag → move window", isOn: Binding(
                    get: { store.config.modifierDrag.moveEnabled },
                    set: { v in store.update { $0.modifierDrag.moveEnabled = v } }
                ))
                Toggle("⌃⌘ + drag → resize window", isOn: Binding(
                    get: { store.config.modifierDrag.resizeEnabled },
                    set: { v in store.update { $0.modifierDrag.resizeEnabled = v } }
                ))
                Text("Hold the chord, left-drag anywhere on a window. Resize uses the nearest edge/corner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Layout") {
                Stepper(value: Binding(
                    get: { store.config.window.gap },
                    set: { v in store.update { $0.window.gap = v } }
                ), in: 0...32, step: 2) {
                    Text("Gap: \(Int(store.config.window.gap)) pt")
                }
            }
        }
    }

    private var windowGestureMap: some View {
        VStack(spacing: 6) {
            Text("pinch out → fullscreen")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("↑ maximize")
                .font(.caption.weight(.medium))
            HStack(spacing: 8) {
                Text("← half")
                    .font(.caption.weight(.medium))
                Text("title bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("half →")
                    .font(.caption.weight(.medium))
            }
            Text("↓ minimize")
                .font(.caption.weight(.medium))
            Text("pinch in → close · diagonals → quarters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(SanneChrome.iconWell, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var keyboard: some View {
        Form {
            Section {
                SannePageHeader(
                    title: "Keyboard",
                    subtitle: "Control + Option chord only — never bare arrows."
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Enable keyboard snap", isOn: Binding(
                    get: { store.config.keyboard.enabled },
                    set: { v in store.update { $0.keyboard.enabled = v } }
                ))
            }

            Section("⌃⌥ + arrows") {
                Toggle("Snap with arrows", isOn: bindKB(\.snapWithArrows))
                Toggle("Cycle thirds on repeated ←/→", isOn: bindKB(\.cycleThirds))
                Text("←/→ half → third → two-thirds · ↑ maximize · ↓ almost-max · ↩ large center")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Multi-display") {
                Toggle("⌃⌥⌘ + ←/→ move to adjacent display", isOn: bindKB(\.moveToAdjacentDisplay))
            }
        }
        .formStyle(.grouped)
    }

    private var apps: some View {
        Form {
            Section {
                SannePageHeader(
                    title: "Apps",
                    subtitle: "Per-app behaviour. Each app can pause part of Sanne while it's frontmost, and separately give some gestures its own actions."
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section("Overrides") {
                if store.config.appOverrides.isEmpty {
                    Text("No app overrides.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.config.appOverrides) { override in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SanneIconBadge(systemImage: "app.fill", size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(override.displayName)
                                        .font(.body.weight(.medium))
                                    Text(override.bundleId)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("Active", isOn: Binding(
                                    get: {
                                        store.config.appOverrides.first(where: { $0.bundleId == override.bundleId })?.disabled ?? true
                                    },
                                    set: { v in
                                        store.update { cfg in
                                            if let i = cfg.appOverrides.firstIndex(where: { $0.bundleId == override.bundleId }) {
                                                cfg.appOverrides[i].disabled = v
                                            }
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .help("When on, Sanne pauses the selected scope for this app.")
                                // Removes the *pause* row only. The app's gesture bindings are a
                                // separate thing the user configured deliberately, so they survive
                                // and stay reachable through the “Gesture bindings only” section
                                // below — deleting them here would be silent data loss.
                                Button(role: .destructive) {
                                    store.update { $0.appOverrides.removeAll { $0.bundleId == override.bundleId } }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove this app’s pause settings. Its gesture bindings are kept.")
                            }
                            Divider()
                                .padding(.vertical, 2)

                            // The row drives two unrelated things; without these labels the pause
                            // picker and the gesture button read as one setting.
                            Text("Pause while frontmost")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Pause", selection: Binding(
                                get: {
                                    store.config.appOverrides.first(where: { $0.bundleId == override.bundleId })?.scope ?? .all
                                },
                                set: { v in
                                    store.update { cfg in
                                        if let i = cfg.appOverrides.firstIndex(where: { $0.bundleId == override.bundleId }) {
                                            cfg.appOverrides[i].scope = v
                                        }
                                    }
                                }
                            )) {
                                ForEach(AppOverrideScope.allCases) { scope in
                                    Text(scope.title).tag(scope)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)

                            Divider()
                                .padding(.vertical, 2)

                            Text("Gesture bindings")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            AppGestureOverridesButton(bundleId: override.bundleId)

                            // Pausing everything outranks the binding layers, so say so rather than
                            // letting the user wonder why their per-app remap never fires.
                            if store.config.isDisabled(forFrontmostBundleId: override.bundleId),
                               BindingResolver.customizedCount(
                                   config: store.config,
                                   scope: .app(bundleId: override.bundleId)
                               ) > 0
                            {
                                Label(
                                    "Sanne is fully paused for this app, so its own gesture bindings won’t run.",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button("Add frontmost app") { addFrontmostApp() }
                Button("Add application…") { addAppViaPicker() }
                Text("Example: pause Magic Mouse only in games, or swap one titlebar gesture just for Xcode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            OrphanAppGestureRemapsSection()
        }
        .formStyle(.grouped)
    }

    private var dock: some View {
        deviceZonePage(
            group: .dock,
            title: "Dock",
            subtitle: "Two fingers on a Dock icon. Enable each gesture and change its action below."
        ) {
            Section {
                Toggle("Dock gestures", isOn: Binding(
                    get: { store.config.dockGestures.enabled },
                    set: { v in store.update { $0.dockGestures.enabled = v } }
                ))
            }
        }
    }

    private var menubar: some View {
        deviceZonePage(
            group: .menubar,
            title: "Menubar",
            subtitle: "Two fingers on the menu bar band. Enable each gesture and change its action below."
        ) {
            Section {
                Toggle("Menubar gestures", isOn: Binding(
                    get: { store.config.menubarGestures.enabled },
                    set: { v in store.update { $0.menubarGestures.enabled = v } }
                ))
            }
        }
    }

    private var trackpad: some View {
        deviceZonePage(
            group: .trackpad,
            title: "Trackpad",
            subtitle: "Free-space taps, drags, and multi-finger swipes. Enable each gesture and change its action below."
        ) {
            if trackpadSystemGestureConflict {
                Section {
                    systemGestureHint
                }
            }

            if store.config.trackpad.threeFingerSwipes, store.config.trackpad.threeFingerDrag {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Three-finger drag is also on and wins — a three-finger swipe will start a drag instead. Turn drag off to use three-finger swipes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Tip-tap needs no System Settings changes. Keep the resting finger still — sliding it cancels the gesture, so two-finger scrolling keeps working.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Sensitivity") {
                Stepper(value: Binding(
                    get: { store.config.trackpad.sensitivity },
                    set: { v in store.update { $0.trackpad.sensitivity = v } }
                ), in: -2...2) {
                    Text("Trackpad: \(store.config.trackpad.sensitivity)")
                }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 72, height: 72)
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sanne")
                        .font(.largeTitle.weight(.semibold))
                    Text("Gestures for Magic Mouse and trackpad")
                        .foregroundStyle(.secondary)
                    Text("Version \(AppVersion.display) · Free & open source")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SanneFeatureRow(
                    systemImage: "computermouse",
                    title: "Silent Magic Mouse taps",
                    detail: "Click without the physical click — left, right, middle, and more."
                )
                SanneFeatureRow(
                    systemImage: "macwindow",
                    title: "Zone-aware window gestures",
                    detail: "Title bar, Dock, and menu bar respond to two-finger swipes."
                )
                SanneFeatureRow(
                    systemImage: "slider.horizontal.3",
                    title: "Opinionated, fully editable",
                    detail: "Sanne Standard defaults on day one; remap anything later."
                )
            }
            .padding(14)
            .background(SanneChrome.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(SanneChrome.subtleBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("License")
                    .font(.headline)
                Text("MIT License — free to use, modify, and distribute. No trial, no paid tier, no account.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    if let url = URL(string: "https://opensource.org/licenses/MIT") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("MIT License text", systemImage: "doc.text")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SanneChrome.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(SanneChrome.subtleBorder, lineWidth: 1)
            )

            HStack(spacing: 10) {
                Button {
                    NotificationCenter.default.post(name: .sanneShowTutorial, object: nil)
                } label: {
                    Label("Tutorial", systemImage: "graduationcap")
                }
                Button {
                    NotificationCenter.default.post(name: .sanneShowCheatSheet, object: nil)
                } label: {
                    Label("Cheat Sheet", systemImage: "list.bullet.rectangle")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                pathRow("Config", "~/Library/Application Support/Sanne/config.json")
                pathRow("Log", LogRing.shared.logFilePath)
                pathRow("Binary", Permissions.processPath)
                Text(TouchDeviceManager.shared.stats)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    private func pathRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Bindings

    private func bindMM(_ keyPath: WritableKeyPath<MagicMouseTapConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.config.magicMouseTaps[keyPath: keyPath] },
            set: { v in store.update { $0.magicMouseTaps[keyPath: keyPath] = v } }
        )
    }

    private func bindKB(_ keyPath: WritableKeyPath<KeyboardConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.config.keyboard[keyPath: keyPath] },
            set: { v in store.update { $0.keyboard[keyPath: keyPath] = v } }
        )
    }

    // MARK: - System gesture conflict

    private var trackpadSystemGestureConflict: Bool {
        store.config.trackpad.threeFingerSwipes
            || store.config.trackpad.fourFingerSwipes
            || store.config.trackpad.fourFingerTap
    }

    /// Registering with MultitouchSupport does not stop macOS from also handling free-space
    /// 3F/4F swipes, so both fire until the user turns the system gesture off.
    private var systemGestureHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("macOS also uses these swipes. Sanne cannot block the system gesture, so turn off the matching entries in System Settings → Trackpad → More Gestures (Swipe between pages, Swipe between full-screen apps, Mission Control, App Exposé) or both will fire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Open Trackpad settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.trackpad") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
        }
    }

    // MARK: - Import / export

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "sanne-config.json"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.exportToFile(url: url)
                importExportMessage = "Exported to \(url.lastPathComponent)"
            } catch {
                importExportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.importFromFile(url: url)
                importExportMessage = "Imported \(url.lastPathComponent)"
            } catch {
                importExportMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Per-app

    private func addFrontmostApp() {
        let candidates = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let bid = app.bundleIdentifier, bid != "app.sanne.Sanne" else { return nil }
                return (bid, app.localizedName ?? bid)
            }

        if let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier,
           bid != "app.sanne.Sanne"
        {
            addOverride(bundleId: bid, displayName: front.localizedName ?? bid)
            return
        }

        if let other = candidates.first {
            addOverride(bundleId: other.0, displayName: other.1)
            return
        }
        importExportMessage = "No other app found — use Add application…"
    }

    private func addAppViaPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let bid = Bundle(url: url)?.bundleIdentifier else {
                importExportMessage = "Could not read bundle id."
                return
            }
            let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            addOverride(bundleId: bid, displayName: name)
        }
    }

    private func addOverride(bundleId: String, displayName: String) {
        if store.config.appOverrides.contains(where: { $0.bundleId == bundleId }) {
            importExportMessage = "\(displayName) is already listed."
            return
        }
        store.update {
            $0.appOverrides.append(AppOverride(bundleId: bundleId, displayName: displayName, disabled: true))
        }
        importExportMessage = "Added \(displayName)"
    }
}
