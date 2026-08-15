import SwiftUI

struct KeyboardPage: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        PreferencesSupport.deviceZonePage(
            group: .keyboard,
            title: "Keyboard",
            subtitle: "Control + Option chord only — never bare arrows. ↓ restores the last frame. Repeat ←/→ cycle thirds."
        ) {
            Section {
                Toggle("Enable keyboard snap", isOn: Binding(
                    get: { store.config.keyboard.enabled },
                    set: { v in store.update { $0.keyboard.enabled = v } }
                ))
                Text("Sanne consumes the chord so Terminal and other apps do not also see the arrow. macOS may ask for Input Monitoring the first time this is on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if store.config.keyboard.enabled && !app.inputMonitoringTrusted {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Input Monitoring is required for keyboard snap.")
                                .font(.callout.weight(.medium))
                            Button("Open Input Monitoring settings") {
                                app.requestInputMonitoring()
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Section("Options") {
                Toggle("Cycle thirds on repeated ←/→", isOn: store.bindKB(\.cycleThirds))
                Text("When on, ←/→ and titlebar long-swipe walk half → third → two-thirds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
