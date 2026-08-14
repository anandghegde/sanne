import CoreGraphics
import Foundation

enum AXFrameWriteMode: Equatable {
    case commit
    case live
}

enum AXLiveWriteKind: Equatable {
    case move
    case resize
}

enum AXFrameWrite {
    static let liveTolerance: CGFloat = 0.5

    static func shouldSkipLive(previous: CGRect?, next: CGRect, tolerance: CGFloat = liveTolerance) -> Bool {
        guard let previous else { return false }
        return abs(previous.minX - next.minX) < tolerance
            && abs(previous.minY - next.minY) < tolerance
            && abs(previous.width - next.width) < tolerance
            && abs(previous.height - next.height) < tolerance
    }

    static func liveKind(previous: CGRect?, next: CGRect, tolerance: CGFloat = liveTolerance) -> AXLiveWriteKind {
        guard let previous else { return .resize }
        let sizeUnchanged = abs(previous.width - next.width) < tolerance
            && abs(previous.height - next.height) < tolerance
        return sizeUnchanged ? .move : .resize
    }
}
