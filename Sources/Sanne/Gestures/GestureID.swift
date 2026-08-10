import Foundation

enum RecognizedGesture: Equatable {
    case swipe(fingers: Int, direction: SwipeDirection)
    case pinch(inward: Bool)
    case tap(fingers: Int)
    case surfaceTap(side: SurfaceSide)
    case threeFingerMiddle
}

enum SwipeDirection: String, Equatable {
    case left, right, up, down
    case upLeft, upRight, downLeft, downRight
}

enum SurfaceSide: String, Equatable {
    case left, right
}
