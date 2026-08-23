import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PresetsPage: View {
    @EnvironmentObject private var store: ConfigStore

    @State private var importExportMessage: String?
    @State private var confirmReset = false
    @State private var pendingPreset: SannePreset?
    @State private var confirmRemaps = false

    private var matching: SannePreset? { SannePreset.matching(store.config) }

    var body: some View {
        PreferencesSupport.detailScroll {
            VStack(alignment: .leading, spacing: 20) {
                SannePageHeader(
                    title: "Presets",
                    subtitle: "Switch the built-in enablement map, or back up your config."
                )

                Form {
                    Section {
                        ForEach(SannePreset.all) { preset in
                            presetRow(preset)
                        }
                        if matching == nil {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Custom")
                                        .font(.body.weight(.medium))
                                    Text("Your enablement no longer matches a built-in preset.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Enablement")
                    } footer: {
                        Text("A preset turns gestures on or off. Remaps, scripts, HUD, and login stay unless you Reset.")
                    }

                    Section {
                        HStack(spacing: 10) {
                            Button("Export config…") { exportConfig() }
                            Button("Import config…") { importConfig() }
                        }
                        if let importExportMessage {
                            Text(importExportMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Backup")
                    } footer: {
                        Text("Import keeps your current config as config.json.bak so you can recover it manually.")
                    }

                    Section {
                        Text("Reset restores Sanne Standard defaults. It first saves config.json.bak, then wipes custom scripts, app remaps, launch-at-login, HUD, and per-gesture overrides.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Reset to Sanne Standard", role: .destructive) {
                            confirmReset = true
                        }
                    } header: {
                        Text("Reset")
                    }
                }
                .frame(maxWidth: 680)
            }
            .confirmationDialog(
                "Reset to Sanne Standard?",
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    store.resetToStandard()
                    importExportMessage = "Reset to Sanne Standard. Previous config saved as config.json.bak."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This wipes custom scripts, app remaps, launch-at-login, HUD, and per-gesture overrides.")
            }
            .confirmationDialog(
                "Keep your remaps?",
                isPresented: $confirmRemaps,
                titleVisibility: .visible
            ) {
                Button("Apply and keep remaps") {
                    if let pendingPreset {
                        store.applyPreset(pendingPreset, keepActionRemaps: true)
                        importExportMessage = "Applied \(pendingPreset.title)."
                    }
                    pendingPreset = nil
                }
                Button("Apply and clear remaps", role: .destructive) {
                    if let pendingPreset {
                        store.applyPreset(pendingPreset, keepActionRemaps: false)
                        importExportMessage = "Applied \(pendingPreset.title) and cleared remaps."
                    }
                    pendingPreset = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingPreset = nil
                }
            } message: {
                Text("You have remapped gestures. Applying a preset changes which gestures are on.")
            }
        }
    }

    private func presetRow(_ preset: SannePreset) -> some View {
        let selected = matching?.id == preset.id
        return Button {
            choose(preset)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(preset.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selected)
    }

    private func choose(_ preset: SannePreset) {
        if matching?.id == preset.id { return }
        if SannePreset.hasActionRemaps(store.config) {
            pendingPreset = preset
            confirmRemaps = true
        } else {
            store.applyPreset(preset, keepActionRemaps: true)
            importExportMessage = "Applied \(preset.title)."
        }
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "sanne-config.json"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.exportToFile(url: url)
                importExportMessage = "Exported to \(url.lastPathComponent)"
            } catch {
                importExportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.importFromFile(url: url)
                importExportMessage = "Imported \(url.lastPathComponent)"
            } catch {
                importExportMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}
