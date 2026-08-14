import Foundation

/// Fired when a remappable slot actually runs. Settings listens and flashes the matching row.
enum GestureActivity {
    static let didFire = Notification.Name("sanneGestureDidFire")
    static let highlightSlot = Notification.Name("sanneHighlightSlot")

    static func announce(slotId: String) {
        NotificationCenter.default.post(
            name: didFire,
            object: nil,
            userInfo: ["slotId": slotId]
        )
    }

    static func highlight(slotId: String) {
        NotificationCenter.default.post(
            name: highlightSlot,
            object: nil,
            userInfo: ["slotId": slotId]
        )
    }
}
