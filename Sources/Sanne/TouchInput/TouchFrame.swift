import Foundation
import CoreGraphics

enum DeviceKind: String, Equatable {
    case builtInTrackpad
    case magicTrackpad
    case magicMouse
    case unknown
}

/// Pure classification of MultitouchSupport + IOKit signals.
/// Built-in and Magic Trackpad go to the trackpad path; Magic Mouse never does.
enum TouchDeviceClassifier {
    struct Signals: Equatable {
        var isBuiltIn: Bool
        var isOpaque: Bool
        var supportsForce: Bool
        var productName: String? = nil
    }

    static func classify(_ s: Signals) -> DeviceKind {
        let name = (s.productName ?? "").lowercased()
        if name.contains("mouse") { return .magicMouse }
        if name.contains("trackpad") {
            return s.isBuiltIn ? .builtInTrackpad : .magicTrackpad
        }
        if s.isBuiltIn { return .builtInTrackpad }
        // Magic Trackpad 2+: external, Force Touch, not an opaque mouse surface.
        if s.supportsForce && !s.isOpaque { return .magicTrackpad }
        if s.isOpaque { return .magicMouse }
        // Magic Mouse 2 often reports opaque=false, force=false, not built-in.
        if !s.supportsForce { return .magicMouse }
        return .unknown
    }

    static func isTrackpad(_ kind: DeviceKind) -> Bool {
        kind == .builtInTrackpad || kind == .magicTrackpad
    }

    static func isMagicMouse(_ kind: DeviceKind) -> Bool {
        kind == .magicMouse
    }
}

enum WakeRebind {
    /// Three attempts; Bluetooth Magic Mouse is often late after lid-open.
    static let attemptDelaysNanoseconds: [UInt64] = [
        200_000_000,
        800_000_000,
        2_000_000_000,
    ]
}

struct TouchPoint: Equatable {
    var id: Int
    var normalized: CGPoint
    var majorAxis: Float
    var minorAxis: Float
    var state: Int
    var phase: TouchPhase
}

enum TouchPhase: Equatable {
    case began
    case moved
    case stationary
    case ended
    case cancelled
}

struct TouchFrame: Equatable {
    var timestamp: Date
    var deviceID: Int64
    var deviceKind: DeviceKind
    var touches: [TouchPoint]
}
