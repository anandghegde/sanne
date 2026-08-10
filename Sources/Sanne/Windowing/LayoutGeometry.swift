import AppKit
import Foundation

enum WindowLayout: String, Equatable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftThird
    case centerThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case maximize
    case center
    case centerLarge
    case almostMaximize
}

enum LayoutGeometry {
    static func targetFrame(layout: WindowLayout, visibleFrameAppKit visible: CGRect, gap: CGFloat) -> CGRect {
        let g = gap
        let x = visible.minX + g
        let y = visible.minY + g
        let w = visible.width - g * 2
        let h = visible.height - g * 2
        let halfW = floor(w / 2)
        let halfH = floor(h / 2)
        let thirdW = floor(w / 3)
        let twoThirdW = w - thirdW
        let colGap = g / 2

        let appKitRect: CGRect
        switch layout {
        case .leftHalf:
            appKitRect = CGRect(x: x, y: y, width: halfW - colGap, height: h)
        case .rightHalf:
            appKitRect = CGRect(x: x + halfW + colGap, y: y, width: halfW - colGap, height: h)
        case .topHalf:
            appKitRect = CGRect(x: x, y: y + halfH + colGap, width: w, height: halfH - colGap)
        case .bottomHalf:
            appKitRect = CGRect(x: x, y: y, width: w, height: halfH - colGap)
        case .topLeft:
            appKitRect = CGRect(x: x, y: y + halfH + colGap, width: halfW - colGap, height: halfH - colGap)
        case .topRight:
            appKitRect = CGRect(x: x + halfW + colGap, y: y + halfH + colGap, width: halfW - colGap, height: halfH - colGap)
        case .bottomLeft:
            appKitRect = CGRect(x: x, y: y, width: halfW - colGap, height: halfH - colGap)
        case .bottomRight:
            appKitRect = CGRect(x: x + halfW + colGap, y: y, width: halfW - colGap, height: halfH - colGap)
        case .leftThird:
            appKitRect = CGRect(x: x, y: y, width: thirdW - colGap, height: h)
        case .centerThird:
            appKitRect = CGRect(x: x + thirdW + colGap, y: y, width: thirdW - colGap * 2, height: h)
        case .rightThird:
            appKitRect = CGRect(x: x + twoThirdW + colGap, y: y, width: thirdW - colGap, height: h)
        case .leftTwoThirds:
            appKitRect = CGRect(x: x, y: y, width: twoThirdW - colGap, height: h)
        case .rightTwoThirds:
            appKitRect = CGRect(x: x + thirdW + colGap, y: y, width: twoThirdW - colGap, height: h)
        case .maximize:
            appKitRect = CGRect(x: x, y: y, width: w, height: h)
        case .center:
            let cw = floor(w * 0.6)
            let ch = floor(h * 0.6)
            appKitRect = CGRect(
                x: visible.midX - cw / 2,
                y: visible.midY - ch / 2,
                width: cw,
                height: ch
            )
        case .centerLarge:
            let cw = floor(w * 0.75)
            let ch = floor(h * 0.8)
            appKitRect = CGRect(
                x: visible.midX - cw / 2,
                y: visible.midY - ch / 2,
                width: cw,
                height: ch
            )
        case .almostMaximize:
            let inset: CGFloat = 24
            appKitRect = CGRect(
                x: x + inset,
                y: y + inset,
                width: w - inset * 2,
                height: h - inset * 2
            )
        }
        return appKitToAX(appKitRect)
    }

    /// Cycle left-side snaps: half → third → two-thirds → half.
    static func nextLeftLayout(after current: WindowLayout?) -> WindowLayout {
        switch current {
        case .leftHalf: return .leftThird
        case .leftThird: return .leftTwoThirds
        case .leftTwoThirds: return .leftHalf
        default: return .leftHalf
        }
    }

    /// Cycle right-side snaps: half → third → two-thirds → half.
    static func nextRightLayout(after current: WindowLayout?) -> WindowLayout {
        switch current {
        case .rightHalf: return .rightThird
        case .rightThird: return .rightTwoThirds
        case .rightTwoThirds: return .rightHalf
        default: return .rightHalf
        }
    }

    /// Convert AppKit rect (bottom-left origin) to AX rect (top-left origin, primary display).
    static func appKitToAX(_ rect: CGRect) -> CGRect {
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let topLeftY = primaryH - rect.maxY
        return CGRect(x: rect.origin.x, y: topLeftY, width: rect.width, height: rect.height)
    }

    static func appKitPointToAX(_ p: CGPoint) -> CGPoint {
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: primaryH - p.y)
    }

    static func screenForAppKitPoint(_ p: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main
    }

    /// Screens ordered left→right by frame midX (physical arrangement).
    static func screensLeftToRight() -> [NSScreen] {
        NSScreen.screens.sorted { $0.frame.midX < $1.frame.midX }
    }

    /// Neighbor screen to the left (−1) or right (+1) of `screen`, or nil at edge.
    static func adjacentScreen(from screen: NSScreen, direction: Int) -> NSScreen? {
        let ordered = screensLeftToRight()
        guard let idx = ordered.firstIndex(where: { $0 == screen }) else { return nil }
        let next = idx + direction
        guard ordered.indices.contains(next) else { return nil }
        return ordered[next]
    }

    static func screenContainingAXFrame(_ frame: CGRect) -> NSScreen? {
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let midAppKit = CGPoint(x: frame.midX, y: primaryH - frame.midY)
        return screenForAppKitPoint(midAppKit)
    }
}
