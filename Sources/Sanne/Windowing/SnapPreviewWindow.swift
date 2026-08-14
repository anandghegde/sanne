import AppKit

@MainActor
final class SnapPreviewController {
    static let shared = SnapPreviewController()

    private var window: NSWindow?
    private var lastAppKitFrame: CGRect?
    private var isShowing = false

    func show(axFrame: CGRect) {
        let appKit = LayoutGeometry.axToAppKit(axFrame)
        if isShowing, let last = lastAppKitFrame,
           abs(last.minX - appKit.minX) < 1,
           abs(last.minY - appKit.minY) < 1,
           abs(last.width - appKit.width) < 1,
           abs(last.height - appKit.height) < 1
        {
            return
        }
        lastAppKitFrame = appKit
        isShowing = true
        if window == nil {
            let w = NSWindow(
                contentRect: appKit,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .floating
            w.ignoresMouseEvents = true
            w.hasShadow = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = PreviewView(frame: NSRect(origin: .zero, size: appKit.size))
            w.contentView = view
            window = w
        }
        window?.setFrame(appKit, display: true)
        window?.orderFrontRegardless()
        window?.contentView?.needsDisplay = true
    }

    func hide() {
        isShowing = false
        lastAppKitFrame = nil
        window?.orderOut(nil)
    }
}

private final class PreviewView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        NSColor.systemBlue.withAlphaComponent(0.22).setFill()
        path.fill()
        NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 2
        path.stroke()
        ctx.flush()
    }
}
