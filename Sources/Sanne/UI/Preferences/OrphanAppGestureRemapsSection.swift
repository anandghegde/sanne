import SwiftUI

/// Settings → Apps section for apps that have their own gesture bindings but no pause row.
///
/// Without this those bindings would be live yet invisible: the pause list is the only other place
/// an app appears, so removing a pause row — or importing someone else's config, or uninstalling the
/// app — would leave remaps that keep firing with no way to see or reset them. Listing them here is
/// also what makes deleting a pause row safe, so that button never has to destroy bindings.
struct OrphanAppGestureRemapsSection: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        if !orphans.isEmpty {
            Section("Gesture bindings only") {
                Text("These apps have their own gesture bindings but aren’t paused. Add one above if you also want to pause Sanne for it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(orphans, id: \.self) { bundleId in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SanneIconBadge(systemImage: "app.fill", size: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ActionCatalog.appDisplayName(bundleId: bundleId))
                                    .font(.body.weight(.medium))
                                Text(bundleId)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        AppGestureOverridesButton(bundleId: bundleId)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    /// Apps with bindings that the pause list doesn't already show.
    ///
    /// An uninstalled app still lists fine — `appDisplayName` falls back to the bundle id — which is
    /// the point: config the user can't see is config they can't fix.
    private var orphans: [String] {
        let listed = Set(store.config.appOverrides.map(\.bundleId))
        return store.config.appsWithGestureOverrides.filter { !listed.contains($0) }
    }
}
