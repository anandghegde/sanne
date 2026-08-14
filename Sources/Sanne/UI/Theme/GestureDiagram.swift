import SwiftUI

/// A drawable description of a gesture: which device, how many fingers, what motion.
/// Rendered by `GestureDiagramView` as a small BetterTouchTool-style tile with finger
/// dots and motion arrows so users can see what a "3-finger drag" actually looks like.
struct GestureDiagram: Hashable {
    enum Device: Hashable {
        case trackpad
        case magicMouse
        case keyboard
    }

    /// Highlighted band on the device surface (where the gesture happens).
    enum Zone: Hashable {
        case none
        case topEdge // titlebar / menubar / mouse top edge
        case bottomEdge // dock
    }

    enum Side: Hashable {
        case left
        case center
        case right
    }

    enum Direction: Hashable {
        case up, down, left, right
        case upLeft, upRight, downLeft, downRight
        case leftRight // bidirectional

        var vector: CGVector {
            switch self {
            case .up: return CGVector(dx: 0, dy: -1)
            case .down: return CGVector(dx: 0, dy: 1)
            case .left: return CGVector(dx: -1, dy: 0)
            case .right: return CGVector(dx: 1, dy: 0)
            case .upLeft: return CGVector(dx: -0.72, dy: -0.72)
            case .upRight: return CGVector(dx: 0.72, dy: -0.72)
            case .downLeft: return CGVector(dx: -0.72, dy: 0.72)
            case .downRight: return CGVector(dx: 0.72, dy: 0.72)
            case .leftRight: return CGVector(dx: 1, dy: 0)
            }
        }
    }

    enum Motion: Hashable {
        case touch
        case tap
        case doubleTap
        case tripleTap
        case tapHoldDrag
        case swipe(Direction)
        case pinchIn
        case pinchOut
        case drag
        case keys
        /// Rest one finger and tap a second one to the given side of it. Carries its own side
        /// rather than reusing `side`, which positions the whole chord instead of one dot.
        case tipTap(Side)
    }

    var device: Device
    var fingers: Int
    var motion: Motion
    var side: Side = .center
    var zone: Zone = .none
    var long: Bool = false

    // MARK: - Convenience

    static func mouse(_ fingers: Int, _ motion: Motion, side: Side = .center, zone: Zone = .none) -> GestureDiagram {
        GestureDiagram(device: .magicMouse, fingers: fingers, motion: motion, side: side, zone: zone)
    }

    static func trackpad(_ fingers: Int, _ motion: Motion, zone: Zone = .none, long: Bool = false) -> GestureDiagram {
        GestureDiagram(device: .trackpad, fingers: fingers, motion: motion, zone: zone, long: long)
    }

    static let keyboard = GestureDiagram(device: .keyboard, fingers: 0, motion: .keys)

    // MARK: - Parse from gesture slot id ("mouse.surface.2.swipe.up", "trackpad.titlebar.2.pinch.in", …)

    static func from(slotId: String) -> GestureDiagram {
        let parts = slotId.split(separator: ".").map(String.init)
        if parts.first == "keyboard" { return .keyboard }
        let device: Device = parts.first == "mouse" ? .magicMouse : .trackpad
        let zoneName = parts.count > 1 ? parts[1] : ""
        let zone: Zone
        switch zoneName {
        case "titlebar", "menubar": zone = .topEdge
        case "dock": zone = .bottomEdge
        default: zone = .none
        }
        let fingers = parts.count > 2 ? Int(parts[2]) ?? 1 : 1
        let motionName = parts.count > 3 ? parts[3] : ""
        let detail = parts.count > 4 ? parts[4] : ""
        let long = parts.last == "long"

        var side: Side = .center
        if detail == "left", motionName == "tap" { side = .left }
        if detail == "right", motionName == "tap" { side = .right }

        let motion: Motion
        switch motionName {
        case "tap": motion = fingers >= 3 ? .touch : .tap
        case "touch": motion = .touch
        case "doubleTap": motion = .doubleTap
        case "doubleTapHold": motion = .tapHoldDrag
        case "pinch": motion = detail == "out" ? .pinchOut : .pinchIn
        case "tipTap": motion = .tipTap(detail == "left" ? .left : .right)
        case "drag": motion = .drag
        case "topEdge": return GestureDiagram(device: device, fingers: fingers, motion: .drag, zone: .topEdge)
        case "swipe":
            switch detail {
            case "up": motion = .swipe(.up)
            case "down": motion = .swipe(.down)
            case "left": motion = .swipe(.left)
            case "right": motion = .swipe(.right)
            case "upLeft": motion = .swipe(.upLeft)
            case "upRight": motion = .swipe(.upRight)
            case "downLeft": motion = .swipe(.downLeft)
            case "downRight": motion = .swipe(.downRight)
            default: motion = .swipe(.leftRight)
            }
        default: motion = .tap
        }
        return GestureDiagram(device: device, fingers: fingers, motion: motion, side: side, zone: zone, long: long)
    }
}

// MARK: - View

/// Small tile that draws the device outline, finger dots, and motion arrows.
struct GestureDiagramView: View {
    let diagram: GestureDiagram
    var size: CGFloat = 40
    var active: Bool = true
    /// Spoken after the device name, e.g. slot title `"tap left"` → "Magic Mouse, tap left."
    var label: String? = nil

    private var accent: Color { active ? Color.accentColor : Color.secondary }

    private var accessibilityName: String {
        let device: String
        switch diagram.device {
        case .magicMouse: device = "Magic Mouse"
        case .trackpad: device = "Trackpad"
        case .keyboard: device = "Keyboard"
        }
        let motion = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let motion, !motion.isEmpty {
            return "\(device), \(motion.lowercased())."
        }
        return "\(device), \(motionPhrase)."
    }

    private var motionPhrase: String {
        switch diagram.motion {
        case .tap:
            switch diagram.side {
            case .left: return "tap left"
            case .right: return "tap right"
            case .center: return "tap"
            }
        case .touch: return diagram.fingers == 1 ? "touch" : "\(diagram.fingers)-finger touch"
        case .doubleTap: return "double tap"
        case .tripleTap: return "triple tap"
        case .tapHoldDrag: return "double-tap hold"
        case .swipe(let dir):
            switch dir {
            case .up: return "swipe up"
            case .down: return "swipe down"
            case .left: return "swipe left"
            case .right: return "swipe right"
            case .upLeft: return "swipe up left"
            case .upRight: return "swipe up right"
            case .downLeft: return "swipe down left"
            case .downRight: return "swipe down right"
            case .leftRight: return "swipe left or right"
            }
        case .pinchIn: return "pinch in"
        case .pinchOut: return "pinch out"
        case .drag: return "drag"
        case .keys: return "keys"
        case .tipTap(let side):
            return side == .left ? "tip-tap left" : "tip-tap right"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            Canvas { context, canvasSize in
                draw(in: &context, canvasSize: canvasSize)
            }
            .padding(size * 0.14)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(.isImage)
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, canvasSize: CGSize) {
        let rect = CGRect(origin: .zero, size: canvasSize)
        switch diagram.device {
        case .trackpad:
            drawTrackpad(&context, rect)
        case .magicMouse:
            drawMouse(&context, rect)
        case .keyboard:
            drawKeyboard(&context, rect)
        }
    }

    private var outline: Color { Color.secondary.opacity(0.55) }
    private var surface: Color { Color.primary.opacity(0.05) }

    private func drawTrackpad(_ context: inout GraphicsContext, _ rect: CGRect) {
        // Trackpad body: landscape rounded rect centered.
        let bodyW = rect.width
        let bodyH = rect.height * 0.86
        let body = CGRect(x: 0, y: (rect.height - bodyH) / 2, width: bodyW, height: bodyH)
        let path = Path(roundedRect: body, cornerRadius: bodyH * 0.18)
        context.fill(path, with: .color(surface))
        context.stroke(path, with: .color(outline), lineWidth: 1.1)

        // Zone band
        if diagram.zone != .none {
            let bandH = bodyH * 0.24
            let bandRect: CGRect = diagram.zone == .topEdge
                ? CGRect(x: body.minX + 1, y: body.minY + 1, width: body.width - 2, height: bandH)
                : CGRect(x: body.minX + 1, y: body.maxY - bandH - 1, width: body.width - 2, height: bandH)
            let band = Path(roundedRect: bandRect, cornerRadius: bandH * 0.35)
            context.fill(band, with: .color(accent.opacity(0.18)))
        }

        drawFingersAndMotion(&context, surfaceRect: body)
    }

    private func drawMouse(_ context: inout GraphicsContext, _ rect: CGRect) {
        // Magic Mouse body: tall capsule centered.
        let bodyW = rect.width * 0.56
        let bodyH = rect.height
        let body = CGRect(x: (rect.width - bodyW) / 2, y: 0, width: bodyW, height: bodyH)
        let path = Path(roundedRect: body, cornerRadius: bodyW * 0.5)
        context.fill(path, with: .color(surface))
        context.stroke(path, with: .color(outline), lineWidth: 1.1)

        if diagram.zone == .topEdge {
            let bandH = bodyH * 0.22
            let bandRect = CGRect(x: body.minX + 1.5, y: body.minY + 1.5, width: body.width - 3, height: bandH)
            let band = Path(roundedRect: bandRect, cornerRadius: bandH * 0.5)
            context.fill(band, with: .color(accent.opacity(0.18)))
        }

        // Split line for left / right taps so the side is obvious.
        if diagram.side != .center {
            var split = Path()
            split.move(to: CGPoint(x: body.midX, y: body.minY + bodyH * 0.1))
            split.addLine(to: CGPoint(x: body.midX, y: body.maxY - bodyH * 0.1))
            context.stroke(
                split,
                with: .color(outline.opacity(0.6)),
                style: StrokeStyle(lineWidth: 0.9, dash: [2.2, 2.2])
            )
        }

        drawFingersAndMotion(&context, surfaceRect: body)
    }

    private func drawKeyboard(_ context: inout GraphicsContext, _ rect: CGRect) {
        let body = CGRect(x: 0, y: rect.height * 0.2, width: rect.width, height: rect.height * 0.6)
        let path = Path(roundedRect: body, cornerRadius: 3)
        context.fill(path, with: .color(surface))
        context.stroke(path, with: .color(outline), lineWidth: 1.1)
        // Key rows
        let keySize = body.height * 0.22
        for row in 0..<2 {
            for col in 0..<4 {
                let key = CGRect(
                    x: body.minX + 3 + CGFloat(col) * (keySize + 2.4),
                    y: body.minY + 3 + CGFloat(row) * (keySize + 2.4),
                    width: keySize, height: keySize
                )
                context.fill(Path(roundedRect: key, cornerRadius: 1.2), with: .color(outline.opacity(0.5)))
            }
        }
    }

    // MARK: Fingers + motion

    private func drawFingersAndMotion(_ context: inout GraphicsContext, surfaceRect: CGRect) {
        // Tip-tap is two fingers in different roles rather than a chord moving together, so it
        // draws its own way instead of going through the shared dot row + arrow layout.
        if case .tipTap(let tapSide) = diagram.motion {
            drawTipTap(&context, surfaceRect: surfaceRect, tapSide: tapSide)
            return
        }

        let fingers = max(0, min(diagram.fingers, 5))
        let dotR: CGFloat = surfaceRect.width > surfaceRect.height
            ? surfaceRect.height * 0.09
            : surfaceRect.width * 0.13

        var center = CGPoint(x: surfaceRect.midX, y: surfaceRect.midY)
        // Bias toward the gesture zone.
        switch diagram.zone {
        case .topEdge: center.y = surfaceRect.minY + surfaceRect.height * 0.24
        case .bottomEdge: center.y = surfaceRect.maxY - surfaceRect.height * 0.28
        case .none: break
        }
        // Side bias for left/right taps on the mouse.
        switch diagram.side {
        case .left: center.x = surfaceRect.midX - surfaceRect.width * 0.24
        case .right: center.x = surfaceRect.midX + surfaceRect.width * 0.24
        case .center: break
        }

        // Leave room for a directional arrow by shifting dots opposite to it.
        var arrowDir: GestureDiagram.Direction?
        if case let .swipe(dir) = diagram.motion { arrowDir = dir }
        if diagram.motion == .drag || diagram.motion == .tapHoldDrag { arrowDir = .right }
        if let d = arrowDir, diagram.zone == .none {
            let v = d.vector
            center.x -= v.dx * surfaceRect.width * 0.14
            center.y -= v.dy * surfaceRect.height * 0.14
        }

        let spacing = dotR * 2.35
        let dots = fingerPositions(count: fingers, center: center, spacing: spacing, rect: surfaceRect)
        // Horizontal clearance so arrows start outside the outermost dots.
        let dotSpanX = CGFloat(max(fingers - 1, 0)) / 2 * spacing + dotR * 1.5

        // Motion first (behind dots where relevant)
        switch diagram.motion {
        case .swipe(let dir):
            let clearance = (dir == .left || dir == .right || dir == .leftRight) ? dotSpanX : dotR * 1.5
            drawArrow(&context, from: center, direction: dir, rect: surfaceRect, double: dir == .leftRight, clearance: clearance)
        case .drag, .tapHoldDrag:
            drawArrow(&context, from: center, direction: .right, rect: surfaceRect, double: false, clearance: dotSpanX)
        case .pinchIn:
            drawPinch(&context, center: CGPoint(x: surfaceRect.midX, y: center.y), rect: surfaceRect, inward: true)
        case .pinchOut:
            drawPinch(&context, center: CGPoint(x: surfaceRect.midX, y: center.y), rect: surfaceRect, inward: false)
        default:
            break
        }

        // Finger dots
        let isPinch = diagram.motion == .pinchIn || diagram.motion == .pinchOut
        if !isPinch {
            for p in dots {
                let dot = Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2))
                context.fill(dot, with: .color(accent))
            }
            // Tap ripple ring
            if diagram.motion == .tap || diagram.motion == .touch,
               let first = dots.first, dots.count == 1
            {
                let ring = Path(ellipseIn: CGRect(
                    x: first.x - dotR * 1.9, y: first.y - dotR * 1.9,
                    width: dotR * 3.8, height: dotR * 3.8
                ))
                context.stroke(ring, with: .color(accent.opacity(0.45)), lineWidth: 1)
            }
        }

        // Repeat-count badge (double / triple tap)
        if diagram.motion == .doubleTap || diagram.motion == .tripleTap || diagram.motion == .tapHoldDrag {
            let label = diagram.motion == .tripleTap ? "3×" : "2×"
            let text = Text(label)
                .font(.system(size: surfaceRect.height * 0.26, weight: .bold, design: .rounded))
                .foregroundColor(accent)
            context.draw(
                context.resolve(text),
                at: CGPoint(x: surfaceRect.minX + surfaceRect.width * 0.16, y: surfaceRect.minY + surfaceRect.height * 0.16),
                anchor: .center
            )
        }
    }

    /// Held anchor dot (solid, with a short underline) plus the tapping dot on `tapSide`
    /// (lighter, with a ripple ring) so the two roles read differently at tile size.
    private func drawTipTap(
        _ context: inout GraphicsContext,
        surfaceRect: CGRect,
        tapSide: GestureDiagram.Side
    ) {
        let dotR = surfaceRect.height * 0.11
        let gap = surfaceRect.width * 0.2
        // Offset the pair away from the tapping side so both dots stay well inside the body.
        let anchorX = surfaceRect.midX + (tapSide == .left ? gap * 0.5 : -gap * 0.5)
        let y = surfaceRect.midY
        let anchor = CGPoint(x: anchorX, y: y)
        let tap = CGPoint(x: tapSide == .left ? anchorX - gap : anchorX + gap, y: y)

        // Ripple on the tapping finger.
        let ring = Path(ellipseIn: CGRect(
            x: tap.x - dotR * 1.85, y: tap.y - dotR * 1.85,
            width: dotR * 3.7, height: dotR * 3.7
        ))
        context.stroke(ring, with: .color(accent.opacity(0.45)), lineWidth: 1)

        let tapDot = Path(ellipseIn: CGRect(
            x: tap.x - dotR, y: tap.y - dotR, width: dotR * 2, height: dotR * 2
        ))
        context.fill(tapDot, with: .color(accent.opacity(0.55)))

        let anchorDot = Path(ellipseIn: CGRect(
            x: anchor.x - dotR, y: anchor.y - dotR, width: dotR * 2, height: dotR * 2
        ))
        context.fill(anchorDot, with: .color(accent))

        // "Held" underline beneath the anchor.
        var held = Path()
        held.move(to: CGPoint(x: anchor.x - dotR * 1.25, y: anchor.y + dotR * 2.1))
        held.addLine(to: CGPoint(x: anchor.x + dotR * 1.25, y: anchor.y + dotR * 2.1))
        context.stroke(held, with: .color(accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private func fingerPositions(count: Int, center: CGPoint, spacing: CGFloat, rect: CGRect) -> [CGPoint] {
        guard count > 0 else { return [] }
        var points: [CGPoint] = []
        let arc: CGFloat = rect.height * 0.045 // slight arch like fingertips
        for i in 0..<count {
            let offset = CGFloat(i) - CGFloat(count - 1) / 2
            let x = center.x + offset * spacing
            let y = center.y - (abs(offset) < 0.6 ? arc : 0)
            points.append(CGPoint(x: x, y: y))
        }
        // Clamp inside surface
        return points.map { p in
            CGPoint(
                x: min(max(p.x, rect.minX + spacing * 0.4), rect.maxX - spacing * 0.4),
                y: min(max(p.y, rect.minY + spacing * 0.4), rect.maxY - spacing * 0.4)
            )
        }
    }

    private func drawArrow(
        _ context: inout GraphicsContext,
        from origin: CGPoint,
        direction: GestureDiagram.Direction,
        rect: CGRect,
        double: Bool,
        clearance: CGFloat = 0
    ) {
        let v = direction.vector
        var len = min(rect.width, rect.height) * (diagram.long ? 0.5 : 0.38)
        let startLen = max(len * 0.32, clearance)
        len = max(len, startLen + min(rect.width, rect.height) * 0.18)
        let start = CGPoint(x: origin.x + v.dx * startLen, y: origin.y + v.dy * startLen)
        let end = CGPoint(x: origin.x + v.dx * len, y: origin.y + v.dy * len)
        strokeArrow(&context, from: start, to: end)
        if double {
            let startL = CGPoint(x: origin.x - v.dx * startLen, y: origin.y - v.dy * startLen)
            let endL = CGPoint(x: origin.x - v.dx * len, y: origin.y - v.dy * len)
            strokeArrow(&context, from: startL, to: endL)
        }
    }

    private func drawPinch(
        _ context: inout GraphicsContext,
        center: CGPoint,
        rect: CGRect,
        inward: Bool
    ) {
        let d = min(rect.width, rect.height) * 0.34
        let a = CGPoint(x: center.x - d, y: center.y + d * 0.55)
        let b = CGPoint(x: center.x + d, y: center.y - d * 0.55)
        if inward {
            strokeArrow(&context, from: a, to: CGPoint(x: center.x - d * 0.22, y: center.y + d * 0.12))
            strokeArrow(&context, from: b, to: CGPoint(x: center.x + d * 0.22, y: center.y - d * 0.12))
        } else {
            strokeArrow(&context, from: CGPoint(x: center.x - d * 0.22, y: center.y + d * 0.12), to: a)
            strokeArrow(&context, from: CGPoint(x: center.x + d * 0.22, y: center.y - d * 0.12), to: b)
        }
        // Two finger dots at arrow bases
        let dotR = min(rect.width, rect.height) * 0.085
        for p in inward ? [a, b] : [CGPoint(x: center.x - d * 0.22, y: center.y + d * 0.12), CGPoint(x: center.x + d * 0.22, y: center.y - d * 0.12)] {
            let dot = Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2))
            context.fill(dot, with: .color(accent))
        }
    }

    private func strokeArrow(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint) {
        var line = Path()
        line.move(to: from)
        line.addLine(to: to)
        context.stroke(line, with: .color(accent), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        // Arrow head
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLen = hypot(to.x - from.x, to.y - from.y) * 0.5
        let size = min(max(headLen, 3.2), 4.6)
        var head = Path()
        head.move(to: CGPoint(
            x: to.x - size * cos(angle - .pi / 5.5),
            y: to.y - size * sin(angle - .pi / 5.5)
        ))
        head.addLine(to: to)
        head.addLine(to: CGPoint(
            x: to.x - size * cos(angle + .pi / 5.5),
            y: to.y - size * sin(angle + .pi / 5.5)
        ))
        context.stroke(head, with: .color(accent), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Labeled row (diagram + title + optional subtitle)

/// Standard settings row: gesture tile on the left, title/subtitle, trailing content (e.g. Toggle).
struct GestureToggleRow: View {
    let diagram: GestureDiagram
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                GestureDiagramView(diagram: diagram, size: 38, active: isOn, label: title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityLabel("Enable \(title)")
    }
}
