import SwiftUI

struct MagicMousePage: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        PreferencesSupport.deviceZonePage(
            group: .magicMouse,
            title: "Magic Mouse",
            subtitle: "Silent taps and multi-finger actions. Enable each gesture and change its action below.",
            dimSlots: !app.hasMagicMouse
        ) {
            Section {
                Toggle("Enable Magic Mouse taps", isOn: Binding(
                    get: { store.config.magicMouseTaps.enabled },
                    set: { v in store.update { $0.magicMouseTaps.enabled = v } }
                ))
                if !app.hasMagicMouse {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "computermouse")
                            .foregroundStyle(.secondary)
                        Text("Connect a Magic Mouse to configure taps.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(0.7)
                } else {
                    Text("Master switch for all Magic Mouse gestures. Works best with a Magic Mouse.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Options") {
                GestureToggleRow(
                    diagram: .mouse(1, .doubleTap),
                    title: "Double / triple tap → multi-click",
                    subtitle: "Double-tap renames files / selects words; triple selects a line or paragraph.",
                    isOn: store.bindMM(\.multiClick)
                )
                GestureToggleRow(
                    diagram: .mouse(1, .tap, side: .left),
                    title: "Gaming mode",
                    subtitle: "Hold the physical right click and tap left to left-click (look + fire).",
                    isOn: store.bindMM(\.gamingMode)
                )
            }
            .opacity(app.hasMagicMouse ? 1 : 0.45)

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
}
