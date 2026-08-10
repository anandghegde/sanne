import Foundation
import CoreGraphics

enum DeviceKind: String, Equatable {
    case builtInTrackpad
    case magicTrackpad
    case magicMouse
    case unknown
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
