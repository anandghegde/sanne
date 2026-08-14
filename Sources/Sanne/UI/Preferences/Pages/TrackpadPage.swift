import AppKit
import SwiftUI

struct TrackpadPage: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        PreferencesSupport.deviceZonePage(
            group: .trackpad,
            title: "Trackpad",
            subtitle: "Free-space taps, drags, and multi-finger swipes. Enable each gesture and change its action below.",
            dimSlots: !app.hasTrackpad
        ) {
            if !app.hasTrackpad {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "rectangle.and.hand.point.up.left")
                            .foregroundStyle(.secondary)
                        Text("Connect a trackpad to configure gestures.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(0.7)
                }
            }

            if trackpadSystemGestureConflict {
                Section {
                    systemGestureHint
                }
            }

            if freeSpaceEnabled(GestureSlots.ID.free3SwipeLeft) || freeSpaceEnabled(GestureSlots.ID.free3SwipeRight),
               freeSpaceEnabled(GestureSlots.ID.free3Drag) {
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

    private func freeSpaceEnabled(_ id: String) -> Bool {
        BindingResolver.resolve(slotId: id, config: store.config)?.enabled == true
    }

    private var trackpadSystemGestureConflict: Bool {
        [
            GestureSlots.ID.free3SwipeLeft,
            GestureSlots.ID.free3SwipeRight,
            GestureSlots.ID.free3SwipeUp,
            GestureSlots.ID.free3SwipeDown,
            GestureSlots.ID.free4SwipeLeft,
            GestureSlots.ID.free4SwipeRight,
            GestureSlots.ID.free4SwipeUp,
            GestureSlots.ID.free4SwipeDown,
            GestureSlots.ID.free4Tap,
        ].contains { freeSpaceEnabled($0) }
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
}
