import SwiftUI

/// Shared visual language inspired by Multitouch.app: soft surfaces, blue selection, icon+title rows.
enum SanneChrome {
    static let sidebarWidth: CGFloat = 168
    static let iconBadgeSize: CGFloat = 28
    static let cornerRadius: CGFloat = 8
    static let rowRadius: CGFloat = 6

    /// Multitouch-like accent for selected chrome (falls back to system accent).
    static var accent: Color { Color.accentColor }

    static var sidebarSelection: Color {
        Color.accentColor.opacity(0.14)
    }

    static var iconWell: Color {
        Color.primary.opacity(0.06)
    }

    static var iconWellSelected: Color {
        Color.accentColor.opacity(0.16)
    }

    static var cardFill: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var subtleBorder: Color {
        Color.primary.opacity(0.08)
    }
}

// MARK: - Icon badge (gesture / feature glyphs)

struct SanneIconBadge: View {
    let systemImage: String
    var selected: Bool = false
    var size: CGFloat = SanneChrome.iconBadgeSize
    var filled: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected || filled ? SanneChrome.iconWellSelected : SanneChrome.iconWell)
            if selected || filled {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.92))
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status pill

struct SanneStatusPill: View {
    enum Kind {
        case ok, warning, error, neutral

        var color: Color {
            switch self {
            case .ok: return .green
            case .warning: return .orange
            case .error: return .red
            case .neutral: return .secondary
            }
        }
    }

    let title: String
    var kind: Kind = .neutral

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(kind.color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(kind.color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Feature / tip row used in onboarding & about

struct SanneFeatureRow: View {
    let systemImage: String
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SanneIconBadge(systemImage: systemImage, size: 32, filled: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Section intro under page titles

struct SannePageHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

// MARK: - Filter chips (gesture editor / cheat sheet)

struct SanneFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gesture glyph from slot id

enum GestureGlyph {
    static func systemImage(forSlotId id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("pinch.in") { return "arrow.down.right.and.arrow.up.left" }
        if lower.contains("pinch.out") { return "arrow.up.left.and.arrow.down.right" }
        if lower.contains("swipe.upleft") || lower.contains("upleft") { return "arrow.up.left" }
        if lower.contains("swipe.upright") || lower.contains("upright") { return "arrow.up.right" }
        if lower.contains("swipe.downleft") || lower.contains("downleft") { return "arrow.down.left" }
        if lower.contains("swipe.downright") || lower.contains("downright") { return "arrow.down.right" }
        if lower.contains("swipe.left") { return "arrow.left" }
        if lower.contains("swipe.right") { return "arrow.right" }
        if lower.contains("swipe.up") { return "arrow.up" }
        if lower.contains("swipe.down") { return "arrow.down" }
        if lower.contains("doubletap") || lower.contains("double.tap") { return "hand.tap.fill" }
        if lower.contains("tap") || lower.contains("touch") { return "hand.tap" }
        if lower.contains("drag") { return "arrow.up.and.down.and.arrow.left.and.right" }
        if lower.contains("mouse") { return "computermouse" }
        if lower.contains("dock") { return "dock.rectangle" }
        if lower.contains("menubar") { return "menubar.rectangle" }
        return "hand.draw"
    }

    static func systemImage(forGroup group: GestureSlots.Group) -> String {
        switch group {
        case .magicMouse: return "computermouse"
        case .titlebar: return "macwindow"
        case .dock: return "dock.rectangle"
        case .menubar: return "menubar.rectangle"
        case .trackpad: return "hand.draw"
        case .keyboard: return "keyboard"
        }
    }
}
