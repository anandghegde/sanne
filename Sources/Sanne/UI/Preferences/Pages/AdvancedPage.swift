import AppKit
import SwiftUI

struct AdvancedPage: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        PreferencesSupport.detailScroll { advancedAbout }
    }

    private var advancedAbout: some View {
        VStack(alignment: .leading, spacing: 20) {
            about

            Form {
                Section {
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
                } header: {
                    Text("Behavior")
                }

                Section {
                    Toggle("Move window to Space", isOn: Binding(
                        get: { store.config.experimental.windowToSpace },
                        set: { v in store.update { $0.experimental.windowToSpace = v } }
                    ))
                    Text("Experimental. Bind “Move to Space left/right” on a gesture. Uses a private Spaces API; failure shows in the HUD.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Experimental")
                }

                Section {
                    UpdateCheckRow()
                } header: {
                    Text("Updates")
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 560)
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

}

private struct UpdateCheckRow: View {
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Check for Updates…") { check() }
                    .disabled(busy)
                if busy {
                    ProgressView().controlSize(.small)
                }
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func check() {
        busy = true
        message = nil
        let current = AppVersion.marketing
        Task.detached {
            let outcome = await Self.fetch(current: current)
            await MainActor.run {
                busy = false
                switch outcome {
                case .upToDate:
                    message = "You’re on \(current)."
                case .available(let release):
                    message = "\(UpdateChecker.stripV(release.tag)) is available."
                    NSWorkspace.shared.open(release.htmlURL)
                case .failed(let reason):
                    message = reason
                }
            }
        }
    }

    private static func fetch(current: String) async -> UpdateChecker.Outcome {
        var request = URLRequest(url: UpdateChecker.latestReleaseURL)
        request.setValue("Sanne/\(current)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                return .failed("No GitHub Release yet.")
            }
            guard let release = UpdateChecker.parseLatest(from: data) else {
                return .failed("Couldn't read the latest release.")
            }
            return UpdateChecker.evaluate(latest: release, current: current)
        } catch {
            return .failed("Couldn't check for updates.")
        }
    }
}

extension AdvancedPage {
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
}
