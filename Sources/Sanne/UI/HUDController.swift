import AppKit

/// The brief overlay naming the action a gesture just fired.
///
/// Deliberately dumb: it knows nothing about config, slots or the action catalog. Callers decide
/// *whether* to announce (`config.hud.enabled` + `ActionCatalog.announcesInHUD`) and *what* to say
/// (`ActionCatalog.title(for:)`); this type only draws it. That keeps the policy in one place and
/// makes this file testable by eye — the only thing it can get wrong is pixels and timing.
@MainActor
final class HUDController {
    static let shared = HUDController()

    /// Visible at full opacity before the fade starts.
    private static let dwell: TimeInterval = 0.55
    /// Fade-out length. `dwell + fade` is the ~0.8 s the gesture feels like it lasted.
    private static let fade: TimeInterval = 0.25

    private static let horizontalPadding: CGFloat = 18
    private static let verticalPadding: CGFloat = 11
    /// Clearance above the bottom of the screen's *content* area. `visibleFrame` already excludes
    /// the Dock, so this only has to lift the HUD clear of whatever sits at the bottom of a window.
    private static let bottomMargin: CGFloat = 96
    private static let cornerRadius: CGFloat = 12
    /// Keeps a long custom-action name from spanning the display.
    private static let maxWidth: CGFloat = 460
    /// Keeps the HUD off both screen edges even on a narrow or scaled display.
    private static let screenMargin: CGFloat = 24

    private var panel: NSPanel?
    private var label: NSTextField?

    /// Monotonic id of the most recent `show`/`hide`, and the single authority on which timers and
    /// animations still speak for the panel.
    ///
    /// Every scheduled continuation captures the value current when it was scheduled and does
    /// nothing unless it still matches. Since both `show` and `hide` bump this *before* touching the
    /// panel, anything already in flight is invalidated at that instant — so a fade completion from
    /// a superseded announce provably cannot order out a panel a newer announce just put on screen,
    /// no matter how the two interleave.
    private var generation = 0

    private init() {}

    /// Shows `title`, replacing whatever is on screen, and schedules the fade.
    func show(title: String) {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        generation += 1
        let token = generation

        let panel = ensurePanel()
        label?.stringValue = text
        resize(panel: panel)

        // A previous fade may still be mid-flight; this supersedes it rather than racing it, so the
        // panel can never be left stranded at partial alpha.
        setAlphaImmediately(1, on: panel)
        panel.orderFrontRegardless()

        let dwell = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.80 : Self.dwell
        DispatchQueue.main.asyncAfter(deadline: .now() + dwell) { [weak self] in
            guard let self else { return }
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                self.hideIfCurrent(token)
            } else {
                self.fadeOut(token: token)
            }
        }
    }

    /// Removes the HUD at once, cancelling any pending fade.
    func hide() {
        generation += 1
        hideIfCurrent(generation)
    }

    private func hideIfCurrent(_ token: Int) {
        guard token == generation, let panel else { return }
        setAlphaImmediately(1, on: panel)
        panel.orderOut(nil)
    }

    // MARK: - Fade

    private func fadeOut(token: Int) {
        guard token == generation, let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fade
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // AppKit types this handler as a non-isolated `@Sendable` closure but always runs it on
            // the main thread, so state that rather than hopping: a `Task { @MainActor in }` would
            // let a newer `show` land between the fade ending and the guard below, which is exactly
            // the interleaving `generation` exists to rule out.
            MainActor.assumeIsolated {
                guard let self, token == self.generation, let panel = self.panel else { return }
                panel.orderOut(nil)
                // Restore *after* ordering out, so an off-screen panel is always ready to be shown
                // opaque and no frame is ever presented at zero alpha.
                self.setAlphaImmediately(1, on: panel)
            }
        })
    }

    /// Sets alpha now, replacing any running animation on the same property.
    ///
    /// Assigning `alphaValue` directly would be overwritten by the remaining frames of an in-flight
    /// fade; a zero-duration animation group on the same key path supersedes it instead.
    private func setAlphaImmediately(_ alpha: CGFloat, on panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = alpha
        }
        panel.alphaValue = alpha
    }

    // MARK: - Panel

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        // Nothing calls `close()` today; these are what keep that harmless if anything ever does,
        // and keep a decorative overlay out of the Window menu and away from the user's grip.
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isExcludedFromWindowsMenu = true
        // Above `.floating`, which the snap preview uses — a snap announces itself over its own
        // preview rather than behind it.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // AppKit's own order-in/out fade would compete with ours.
        panel.animationBehavior = .none

        let background = NSVisualEffectView(frame: panel.contentLayoutRect)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Self.cornerRadius
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        // `resize` sets the panel width explicitly, so when a name is too long for the display the
        // label must yield and truncate rather than fight for room it cannot have. Measurement is
        // unaffected: `fittingSize` applies its own compression at priority 50, well below this.
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)

        panel.contentView = background

        // "Inset from both sides, vertically centred, truncate under pressure", stated once — so the
        // per-gesture path only moves the panel and never lays out its contents.
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Self.horizontalPadding),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -Self.horizontalPadding),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor)
        ])

        self.panel = panel
        self.label = label
        return panel
    }

    /// Sizes the panel to its text and centres it near the bottom of the active screen.
    private func resize(panel: NSPanel) {
        // The screen under the cursor, which is where the gesture happened — not necessarily the
        // one holding the menu bar. Resolved before measuring, because how wide the text may be
        // depends on how wide that screen is. No screen at all means nowhere to draw.
        let cursor = NSEvent.mouseLocation
        guard let label,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) })
                  ?? NSScreen.main
                  ?? NSScreen.screens.first
        else { return }
        let visible = screen.visibleFrame

        // Room for text after leaving `screenMargin` at each screen edge and the panel's own
        // padding inside that, so a long custom-action name truncates instead of overflowing.
        let textLimit = max(0, min(Self.maxWidth, visible.width - (Self.screenMargin + Self.horizontalPadding) * 2))
        label.preferredMaxLayoutWidth = textLimit
        let textSize = label.fittingSize
        let width = min(textSize.width, textLimit) + Self.horizontalPadding * 2
        let height = textSize.height + Self.verticalPadding * 2

        panel.setFrame(
            NSRect(
                x: (visible.midX - width / 2).rounded(),
                y: (visible.minY + Self.bottomMargin).rounded(),
                width: width.rounded(.up),
                height: height.rounded(.up)
            ),
            display: true
        )
    }
}

/// Refuses focus outright.
///
/// `.nonactivatingPanel` plus `ignoresMouseEvents` already make this unreachable in practice; saying
/// it in the type means no future style-mask edit can quietly turn the HUD into something that
/// steals the user's key window mid-gesture.
private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
