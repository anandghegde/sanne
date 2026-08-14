import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppsPage: View {
    @EnvironmentObject private var store: ConfigStore

    @State private var appsError: String?
    @State private var showRunningApps = false

    var body: some View {
        PreferencesSupport.detailScroll {
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
                            appOverrideRow(override)
                        }
                    }
                }

                Section {
                    Button("Add running app…") { showRunningApps = true }
                    Button("Add application…") { addAppViaPicker() }
                    if let appsError {
                        Text(appsError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Example: pause Magic Mouse only in games, or swap one titlebar gesture just for Xcode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                OrphanAppGestureRemapsSection()
            }
            .formStyle(.grouped)
            .sheet(isPresented: $showRunningApps) {
                runningAppsSheet
            }
        }
    }

    private func appOverrideRow(_ override: AppOverride) -> some View {
        let remaps = BindingResolver.customizedCount(
            config: store.config,
            scope: .app(bundleId: override.bundleId)
        )
        let pauseLine = override.isActive ? "Pause: \(override.scope.title)" : "Not pausing"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                appIconView(bundleId: override.bundleId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(override.displayName)
                        .font(.body.weight(.medium))
                    Text("\(pauseLine) · \(remaps) remap\(remaps == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Button(role: .destructive) {
                    store.update { $0.appOverrides.removeAll { $0.bundleId == override.bundleId } }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove this app’s pause settings. Its gesture bindings are kept.")
            }

            Picker("Pause Sanne while frontmost", selection: Binding(
                get: {
                    if let current = store.config.appOverrides.first(where: { $0.bundleId == override.bundleId }) {
                        return current.isActive ? current.scope.rawValue : "off"
                    }
                    return "off"
                },
                set: { raw in
                    store.update { cfg in
                        guard let i = cfg.appOverrides.firstIndex(where: { $0.bundleId == override.bundleId }) else { return }
                        if raw == "off" {
                            cfg.appOverrides[i].isActive = false
                        } else if let scope = AppOverrideScope(rawValue: raw) {
                            cfg.appOverrides[i].isActive = true
                            cfg.appOverrides[i].scope = scope
                        }
                    }
                }
            )) {
                Text("Don’t pause").tag("off")
                ForEach(AppOverrideScope.allCases) { scope in
                    Text(scope.title).tag(scope.rawValue)
                }
            }
            .help("When a scope is selected, Sanne pauses that part while this app is frontmost.")

            AppGestureOverridesButton(bundleId: override.bundleId)

            if store.config.isDisabled(forFrontmostBundleId: override.bundleId), remaps > 0 {
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

    private func appIconView(bundleId: String) -> some View {
        let image: NSImage = {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        }()
        return Image(nsImage: image)
            .resizable()
            .frame(width: 26, height: 26)
            .cornerRadius(6)
    }

    private var runningAppsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Running apps")
                .font(.headline)
            List(runningRegularApps, id: \.0) { bid, name in
                Button {
                    addOverride(bundleId: bid, displayName: name)
                    showRunningApps = false
                } label: {
                    HStack {
                        appIconView(bundleId: bid)
                        Text(name)
                        Spacer()
                        Text(bid)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack {
                Spacer()
                Button("Cancel") { showRunningApps = false }
            }
        }
        .padding(16)
        .frame(width: 420, height: 360)
    }

    private var runningRegularApps: [(String, String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let bid = app.bundleIdentifier, bid != "app.sanne.Sanne" else { return nil }
                return (bid, app.localizedName ?? bid)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
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
                appsError = "Could not read bundle id."
                return
            }
            let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            addOverride(bundleId: bid, displayName: name)
        }
    }

    private func addOverride(bundleId: String, displayName: String) {
        if store.config.appOverrides.contains(where: { $0.bundleId == bundleId }) {
            appsError = "\(displayName) is already listed."
            return
        }
        store.update {
            $0.appOverrides.append(AppOverride(bundleId: bundleId, displayName: displayName, isActive: true))
        }
        appsError = nil
    }
}
