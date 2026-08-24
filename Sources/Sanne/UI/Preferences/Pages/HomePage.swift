import AppKit
import SwiftUI

struct HomePage: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    @AppStorage(WelcomePrefs.completedKey) private var hasCompletedWelcome = false
    @AppStorage(TutorialPrefs.completedKey) private var tutorialCompleted = false
    @AppStorage(WelcomePrefs.tutorialOfferDismissedKey) private var tutorialOfferDismissed = false
    @State private var dismissedConflicts: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SannePageHeader(
                    title: "Home",
                    subtitle: "Status, quick toggles, and shortcuts. Everything stays on this Mac."
                )

                statusCard

                if store.safeMode {
                    safeModeBanner
                }

                if !visibleConflicts.isEmpty {
                    conflictBanner
                }

                if WelcomePrefs.shouldOfferTutorial(
                    hasCompletedWelcome: hasCompletedWelcome,
                    tutorialCompleted: tutorialCompleted,
                    offerDismissed: tutorialOfferDismissed
                ) {
                    tutorialOfferBanner
                }

                Form {
                    Section {
                        Toggle("Pause all gestures", isOn: Binding(
                            get: { store.config.paused },
                            set: { v in store.update { $0.paused = v } }
                        ))
                    } header: {
                        Text("Pause")
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
                        Toggle("Haptic feedback", isOn: Binding(
                            get: { store.config.window.haptics },
                            set: { v in store.update { $0.window.haptics = v } }
                        ))
                        Toggle("Action name overlay", isOn: Binding(
                            get: { store.config.hud.enabled },
                            set: { v in store.update { $0.hud.enabled = v } }
                        ))
                        Toggle("Snap preview overlay", isOn: Binding(
                            get: { store.config.window.showPreview },
                            set: { v in store.update { $0.window.showPreview = v } }
                        ))
                    } header: {
                        Text("Behavior")
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
                            Text("\(modified) gesture\(modified == 1 ? "" : "s") remapped — edit on the device page or Advanced → All bindings")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Help")
                    }
                }
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
                    Text(app.connectedDeviceLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SanneStatusPill(
                        title: app.isPaused ? "Paused" : ((app.multitouchRunning || app.hasMagicMouse) ? "Running" : "Idle"),
                        kind: app.isPaused ? .warning : ((app.multitouchRunning || app.hasMagicMouse) ? .ok : .neutral)
                    )
                    SanneStatusPill(
                        title: app.accessibilityTrusted ? "Accessibility" : "Needs Accessibility",
                        kind: app.accessibilityTrusted ? .ok : .error
                    )
                    if store.config.keyboard.enabled {
                        SanneStatusPill(
                            title: app.inputMonitoringTrusted ? "Input Monitoring" : "Needs Input Monitoring",
                            kind: app.inputMonitoringTrusted ? .ok : .warning
                        )
                    }
                }
                HStack(spacing: 8) {
                    if app.hasTrackpad {
                        SanneStatusPill(
                            title: app.multitouchRunning ? "Trackpad active" : "Trackpad inactive",
                            kind: app.multitouchRunning ? .ok : .warning
                        )
                    }
                    if app.hasMagicMouse {
                        SanneStatusPill(title: "Magic Mouse", kind: .ok)
                    } else {
                        SanneStatusPill(title: "No Magic Mouse", kind: .neutral)
                    }
                    if let err = app.multitouchError {
                        SanneStatusPill(title: "Multitouch error", kind: .error)
                            .help(err)
                    }
                }
            }

            if !app.accessibilityTrusted {
                Button("Grant Accessibility") {
                    app.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                }
                .keyboardShortcut(.defaultAction)
            }
            if store.config.keyboard.enabled && !app.inputMonitoringTrusted {
                Button("Grant Input Monitoring") {
                    app.requestInputMonitoring()
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

    private var visibleConflicts: [String] {
        app.conflicts.filter { !dismissedConflicts.contains($0) }
    }

    private var conflictBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Also running: \(visibleConflicts.joined(separator: ", ")). Using both can break recognition.")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if !store.config.paused {
                        Button("Pause Sanne") {
                            store.update { $0.paused = true }
                        }
                    }
                    Button("Dismiss") {
                        dismissedConflicts.formUnion(visibleConflicts)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Also running: \(visibleConflicts.joined(separator: ", ")). Using both can break recognition.")
    }

    private var tutorialOfferBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Take the 60-second tutorial")
                    .font(.callout.weight(.medium))
                Text("Try silent taps and titlebar snap, then you’re done.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Not now") {
                tutorialOfferDismissed = true
                WelcomePrefs.dismissTutorialOffer()
            }
            .foregroundStyle(.secondary)
            Button("Start") {
                NotificationCenter.default.post(name: .sanneShowTutorial, object: nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var safeModeBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Safe mode")
                    .font(.callout.weight(.medium))
                Text("Option was held at launch. Sanne Standard is in memory; your config.json was not loaded or saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusSummary: String {
        if store.safeMode { return "Safe mode — Standard defaults. Relaunch without Option to load your config." }
        if !app.accessibilityTrusted { return "Grant Accessibility to move windows and recognize gestures." }
        if store.config.keyboard.enabled && !app.inputMonitoringTrusted {
            return "Grant Input Monitoring to enable keyboard snap."
        }
        if app.isPaused { return "All gestures are paused." }
        if app.isEffectivelyPaused {
            let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "this app"
            return "Paused for \(name) via app override."
        }
        if app.multitouchRunning || app.hasMagicMouse { return "Gestures are active." }
        if app.hasTrackpad { return "Waiting for trackpad…" }
        return "Waiting for multitouch devices…"
    }
}
