import SwiftUI

struct CheatSheetView: View {
    @State private var query = ""
    @State private var categoryFilter: GestureCatalog.Entry.Category?

    private var filtered: [GestureCatalog.Entry] {
        GestureCatalog.all.filter { entry in
            if let categoryFilter, entry.category != categoryFilter { return false }
            return GestureCatalog.matches(entry, query: query)
        }
    }

    private var grouped: [(GestureCatalog.Entry.Category, [GestureCatalog.Entry])] {
        let cats = GestureCatalog.Entry.Category.allCases
        return cats.compactMap { cat in
            let items = filtered.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search gestures…", text: $query)
                        .textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SanneFilterChip(title: "All", selected: categoryFilter == nil) {
                            categoryFilter = nil
                        }
                        ForEach(GestureCatalog.Entry.Category.allCases) { cat in
                            SanneFilterChip(title: cat.rawValue, selected: categoryFilter == cat) {
                                categoryFilter = cat
                            }
                        }
                    }
                }
            }
            .padding(14)

            Divider().opacity(0.6)

            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No matches")
                        .font(.headline)
                    Text("Try a different search or clear the filter.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.0) { cat, items in
                        Section {
                            ForEach(items) { entry in
                                HStack(alignment: .center, spacing: 12) {
                                    GestureDiagramView(diagram: Self.diagram(for: entry), size: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.gesture)
                                            .font(.body.weight(.medium))
                                        Text(entry.action)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 3)
                            }
                        } header: {
                            Label(cat.rawValue, systemImage: cat.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 580, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Visual diagram for each cheat sheet entry.
    static func diagram(for entry: GestureCatalog.Entry) -> GestureDiagram {
        switch entry.id {
        // Titlebar
        case "tb-half-l": return .trackpad(2, .swipe(.left), zone: .topEdge)
        case "tb-half-r": return .trackpad(2, .swipe(.right), zone: .topEdge)
        case "tb-third-l": return .trackpad(2, .swipe(.left), zone: .topEdge, long: true)
        case "tb-third-r": return .trackpad(2, .swipe(.right), zone: .topEdge, long: true)
        case "tb-max": return .trackpad(2, .swipe(.up), zone: .topEdge)
        case "tb-center": return .trackpad(2, .swipe(.up), zone: .topEdge, long: true)
        case "tb-min": return .trackpad(2, .swipe(.down), zone: .topEdge)
        case "tb-q-tl": return .trackpad(2, .swipe(.upLeft), zone: .topEdge)
        case "tb-q-tr": return .trackpad(2, .swipe(.upRight), zone: .topEdge)
        case "tb-q-bl": return .trackpad(2, .swipe(.downLeft), zone: .topEdge)
        case "tb-q-br": return .trackpad(2, .swipe(.downRight), zone: .topEdge)
        case "tb-close": return .trackpad(2, .pinchIn, zone: .topEdge)
        case "tb-fs": return .trackpad(2, .pinchOut, zone: .topEdge)
        case "tb-display": return .trackpad(3, .swipe(.leftRight), zone: .topEdge)
        case "tb-restore": return .trackpad(2, .doubleTap, zone: .topEdge)
        // Magic Mouse
        case "mm-left": return .mouse(1, .tap, side: .left)
        case "mm-right": return .mouse(1, .tap, side: .right)
        case "mm-multi": return .mouse(1, .doubleTap)
        case "mm-2f-mid": return .mouse(2, .touch)
        case "mm-3f-mid": return .mouse(3, .touch)
        case "mm-drag": return .mouse(1, .tapHoldDrag)
        case "mm-2f-mc": return .mouse(2, .doubleTap)
        case "mm-2f-up": return .mouse(2, .swipe(.up))
        case "mm-2f-down": return .mouse(2, .swipe(.down))
        case "mm-2f-lr": return .mouse(2, .swipe(.leftRight))
        case "mm-2f-top": return .mouse(2, .drag, zone: .topEdge)
        // Dock
        case "dock-up": return .trackpad(2, .swipe(.up), zone: .bottomEdge)
        case "dock-down": return .trackpad(2, .swipe(.down), zone: .bottomEdge)
        case "dock-new": return .trackpad(2, .pinchOut, zone: .bottomEdge)
        case "dock-quit": return .trackpad(2, .pinchIn, zone: .bottomEdge)
        // Menubar
        case "mb-next": return .trackpad(2, .swipe(.right), zone: .topEdge)
        case "mb-prev": return .trackpad(2, .swipe(.left), zone: .topEdge)
        case "mb-hide": return .trackpad(2, .swipe(.down), zone: .topEdge)
        case "mb-unmin": return .trackpad(2, .swipe(.up), zone: .topEdge)
        // Trackpad
        case "tp-mid": return .trackpad(3, .tap)
        case "tp-drag": return .trackpad(3, .drag)
        // Keyboard & modifier drag
        case "md-move", "md-resize": return .trackpad(1, .drag)
        default: return .keyboard
        }
    }
}
