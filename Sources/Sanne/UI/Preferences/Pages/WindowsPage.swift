import SwiftUI

struct WindowsPage: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        PreferencesSupport.deviceZonePage(
            group: .titlebar,
            extraGroups: [.dock, .menubar],
            title: "Windows",
            subtitle: "Title bar, Dock, and menu bar. Remap each gesture below."
        ) {
            Section {
                Toggle("Titlebar window gestures", isOn: Binding(
                    get: { store.config.titlebarGestures.enabled },
                    set: { v in store.update { $0.titlebarGestures.enabled = v } }
                ))
                windowGestureMap
                    .padding(.vertical, 4)
            }

            Section("Dock") {
                Toggle("Dock gestures", isOn: Binding(
                    get: { store.config.dockGestures.enabled },
                    set: { v in store.update { $0.dockGestures.enabled = v } }
                ))
                Text("Two fingers on a Dock icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menubar") {
                Toggle("Menubar gestures", isOn: Binding(
                    get: { store.config.menubarGestures.enabled },
                    set: { v in store.update { $0.menubarGestures.enabled = v } }
                ))
                Text("Two fingers on the menu bar band.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Toggle("Cycle thirds on long swipe", isOn: store.bindKB(\.cycleThirds))
                Text("A longer left/right swipe walks half → third → two-thirds. Same policy as ⌃⌥ ←/→.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Snap preview overlay", isOn: Binding(
                    get: { store.config.window.showPreview },
                    set: { v in store.update { $0.window.showPreview = v } }
                ))
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
                Text("← half · keep going for thirds")
                    .font(.caption.weight(.medium))
                Text("title bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("keep going for thirds · half →")
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
}
