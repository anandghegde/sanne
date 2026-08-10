import SwiftUI

/// Settings → Apps control that opens the gesture editor scoped to a single app.
///
/// Owns its own presentation state so the Apps tab stays a plain list of rows: presenting the sheet
/// from there would mean threading a "which app is being edited" `@State` through the whole tab.
struct AppGestureOverridesButton: View {
    let bundleId: String

    @EnvironmentObject private var store: ConfigStore
    @State private var editing = false
    @State private var confirmingClear = false

    var body: some View {
        HStack(spacing: 8) {
            Button("Customize gestures…") { editing = true }
                .buttonStyle(.bordered)
                .controlSize(.small)

            if changedCount > 0 {
                Text("\(changedLabel) changed")
                    .font(.caption)
                    .foregroundStyle(.orange)

                // Bordered rather than prominent: it sits beside the primary action and destroys
                // config, so it should read as available, not inviting.
                Button("Clear", role: .destructive) { confirmingClear = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remove this app's own gesture bindings")
            } else {
                Text("Follows your global bindings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $editing) {
            AppGestureEditorSheet(bundleId: bundleId) { editing = false }
                // Sheets inherit the environment, but passing the store explicitly keeps the editor
                // working wherever this button gets embedded.
                .environmentObject(store)
        }
        .confirmationDialog(
            "Clear \(changedLabel) for \(appName)?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear \(changedLabel)", role: .destructive) {
                store.update { $0.clearAllGestureOverrides(scope: .app(bundleId: bundleId)) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These gestures go back to following your global bindings. Nothing else changes.")
        }
    }

    private var changedCount: Int {
        BindingResolver.customizedCount(config: store.config, scope: .app(bundleId: bundleId))
    }

    /// Written once so the row, the dialog title and its confirm button can never disagree — and so
    /// a single binding never reads "1 gestures".
    private var changedLabel: String {
        changedCount == 1 ? "1 gesture" : "\(changedCount) gestures"
    }

    private var appName: String {
        ActionCatalog.appDisplayName(bundleId: bundleId)
    }
}

/// Chrome around `GestureEditorView` for the app-scoped case.
///
/// The editor is scope-agnostic, so all this adds is a "which app" header and a way out. There is no
/// Cancel because every row writes through `ConfigStore` immediately, exactly as the global tab does.
private struct AppGestureEditorSheet: View {
    let bundleId: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SanneIconBadge(systemImage: "app.fill", size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gestures for \(ActionCatalog.appDisplayName(bundleId: bundleId))")
                        .font(.headline)
                    Text(bundleId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Escape rather than Return: the editor's search field is focused for typing, and
                // Return there should never dismiss the sheet.
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            GestureEditorView(scope: .app(bundleId: bundleId))
        }
        .frame(width: 720, height: 640)
    }
}
