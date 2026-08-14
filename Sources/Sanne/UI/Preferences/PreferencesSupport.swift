import SwiftUI

/// Shared Settings chrome used by the page files. Keep page views free of shell layout.
enum PreferencesSupport {
    @ViewBuilder
    static func detailScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    /// Device/zone pages: master switches + tuning share one scroll with the remappable slots.
    /// GestureEditorView owns that scroll (List under a fixed toolbar). Do not wrap this
    /// in another Form or ScrollView — two scroll views fight for height on macOS.
    static func deviceZonePage<Top: View>(
        group: GestureSlots.Group,
        extraGroups: [GestureSlots.Group] = [],
        title: String,
        subtitle: String,
        dimSlots: Bool = false,
        @ViewBuilder top: () -> Top
    ) -> some View {
        GestureEditorView(
            fixedGroup: group,
            extraGroups: extraGroups,
            pageTitle: title,
            pageSubtitle: subtitle,
            dimSlots: dimSlots,
            header: top
        )
    }
}

extension ConfigStore {
    func bindMM(_ keyPath: WritableKeyPath<MagicMouseTapConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.config.magicMouseTaps[keyPath: keyPath] },
            set: { v in self.update { $0.magicMouseTaps[keyPath: keyPath] = v } }
        )
    }

    func bindKB(_ keyPath: WritableKeyPath<KeyboardConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.config.keyboard[keyPath: keyPath] },
            set: { v in self.update { $0.keyboard[keyPath: keyPath] = v } }
        )
    }
}
