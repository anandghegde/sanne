import SwiftUI

/// Menu / notification hook so Settings can open on a specific sidebar page.
enum PreferencesRoute {
    static let selectTab = Notification.Name("sanneSelectPreferencesTab")
    static var pending: String?

    static let home = "home"
    static let debug = "debug"
    static let about = "about"
    static let bindings = "bindings"
    static let magicMouse = "magicMouse"
    static let trackpad = "trackpad"
    static let windows = "windows"
    static let keyboard = "keyboard"
    static let apps = "apps"
    static let presets = "presets"

    static func route(for group: GestureSlots.Group) -> String {
        switch group {
        case .magicMouse: return magicMouse
        case .trackpad: return trackpad
        case .titlebar, .dock, .menubar: return windows
        case .keyboard: return keyboard
        }
    }

    static func request(_ tab: String) {
        pending = tab
        NotificationCenter.default.post(
            name: selectTab,
            object: nil,
            userInfo: ["tab": tab]
        )
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var app: AppController
    @EnvironmentObject private var store: ConfigStore

    private enum Tab: String, CaseIterable, Identifiable, Hashable {
        case general = "Home"
        case magicMouse = "Magic Mouse"
        case trackpad = "Trackpad"
        case windows = "Windows"
        case keyboard = "Keyboard"
        case apps = "Apps"
        case presets = "Presets"
        case advanced = "About & Support"
        case bindings = "All bindings"
        case debug = "Debug Log"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: return "house.fill"
            case .magicMouse: return "computermouse.fill"
            case .trackpad: return "rectangle.and.hand.point.up.left.fill"
            case .windows: return "macwindow"
            case .keyboard: return "keyboard.fill"
            case .apps: return "app.badge.fill"
            case .presets: return "square.stack.3d.up.fill"
            case .advanced: return "info.circle.fill"
            case .bindings: return "slider.horizontal.3"
            case .debug: return "doc.text.magnifyingglass"
            }
        }

        var tint: Color {
            switch self {
            case .general: return .blue
            case .magicMouse: return .pink
            case .trackpad: return .mint
            case .windows: return .indigo
            case .keyboard: return .gray
            case .apps: return .orange
            case .presets: return .purple
            case .advanced: return .brown
            case .bindings: return .teal
            case .debug: return .gray
            }
        }
    }

    @State private var tab: Tab? = .general
    @State private var searchQuery = ""

    private var searchHits: [SettingsSearch.Hit] {
        SettingsSearch.hits(query: searchQuery)
    }

    var body: some View {
        // Manual sidebar, not NavigationSplitView. A split view + grouped Form in an
        // NSHostingController window reports the Form's full content height, then the
        // window clips the sidebar, page title, and top rows (and the Form will not scroll).
        VStack(spacing: 0) {
            searchField
            Divider()
            HStack(spacing: 0) {
                List(Tab.allCases, selection: $tab) { t in
                    Label {
                        Text(t.rawValue)
                    } icon: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                .fill(t.tint)
                            Image(systemName: t.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 21, height: 21)
                        .shadow(color: t.tint.opacity(0.35), radius: 1.5, y: 0.5)
                    }
                    .tag(t)
                }
                .listStyle(.sidebar)
                .frame(width: SanneChrome.sidebarWidth)

                Divider()

                Group {
                    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        switch tab ?? .general {
                        case .general: HomePage()
                        case .magicMouse: MagicMousePage()
                        case .trackpad: TrackpadPage()
                        case .windows: WindowsPage()
                        case .keyboard: KeyboardPage()
                        case .apps: AppsPage()
                        case .presets: PresetsPage()
                        case .advanced: AdvancedPage()
                        case .bindings: GestureEditorView()
                        case .debug: DebugLogView()
                        }
                    } else {
                        searchResults
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .onAppear { applyPendingRoute() }
        .onReceive(NotificationCenter.default.publisher(for: PreferencesRoute.selectTab)) { note in
            let raw = (note.userInfo?["tab"] as? String) ?? PreferencesRoute.pending
            applyRoute(raw)
        }
        .onReceive(NotificationCenter.default.publisher(for: GestureActivity.didFire)) { note in
            guard let slotId = note.userInfo?["slotId"] as? String,
                  let slot = GestureSlots.slot(id: slotId)
            else { return }
            searchQuery = ""
            applyRoute(PreferencesRoute.route(for: slot.group))
            DispatchQueue.main.async {
                GestureActivity.highlight(slotId: slotId)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search settings…", text: $searchQuery)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search settings")
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchResults: some View {
        Group {
            if searchHits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No matches for “\(searchQuery)”")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchHits) { hit in
                    Button {
                        open(hit)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.title)
                                .foregroundStyle(.primary)
                            Text(hit.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
    }

    private func open(_ hit: SettingsSearch.Hit) {
        searchQuery = ""
        applyRoute(hit.route)
        if let slotId = hit.slotId {
            DispatchQueue.main.async {
                GestureActivity.highlight(slotId: slotId)
            }
        }
    }

    private func applyPendingRoute() {
        applyRoute(PreferencesRoute.pending)
    }

    private func applyRoute(_ raw: String?) {
        guard let raw else { return }
        switch raw {
        case PreferencesRoute.home:
            tab = .general
            PreferencesRoute.pending = nil
        case PreferencesRoute.debug:
            tab = .debug
            PreferencesRoute.pending = nil
        case PreferencesRoute.about:
            tab = .advanced
            PreferencesRoute.pending = nil
        case PreferencesRoute.bindings:
            tab = .bindings
            PreferencesRoute.pending = nil
        case PreferencesRoute.magicMouse:
            tab = .magicMouse
            PreferencesRoute.pending = nil
        case PreferencesRoute.trackpad:
            tab = .trackpad
            PreferencesRoute.pending = nil
        case PreferencesRoute.windows:
            tab = .windows
            PreferencesRoute.pending = nil
        case PreferencesRoute.keyboard:
            tab = .keyboard
            PreferencesRoute.pending = nil
        case PreferencesRoute.apps:
            tab = .apps
            PreferencesRoute.pending = nil
        case PreferencesRoute.presets:
            tab = .presets
            PreferencesRoute.pending = nil
        default:
            break
        }
    }
}
