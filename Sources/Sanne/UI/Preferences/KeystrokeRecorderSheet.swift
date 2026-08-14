import AppKit
import CoreGraphics
import SwiftUI

struct KeystrokeRecorderSheet: View {
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
