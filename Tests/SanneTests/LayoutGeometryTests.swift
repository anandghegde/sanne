import XCTest
@testable import SanneKit

final class LayoutGeometryTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1000, height: 800)

    func testEveryLayoutAtGapZeroAndEight() {
        for gap: CGFloat in [0, 8] {
            for layout in allLayouts {
                let frame = LayoutGeometry.targetFrame(
                    layout: layout,
                    visibleFrameAppKit: visible,
                    gap: gap
                )
                XCTAssertGreaterThan(frame.width, 0, "\(layout) gap \(gap)")
                XCTAssertGreaterThan(frame.height, 0, "\(layout) gap \(gap)")
            }
        }
    }

    func testThirdsFillTheWidth() {
        let gap: CGFloat = 8
        let left = LayoutGeometry.targetFrame(layout: .leftThird, visibleFrameAppKit: visible, gap: gap)
        let center = LayoutGeometry.targetFrame(layout: .centerThird, visibleFrameAppKit: visible, gap: gap)
        let right = LayoutGeometry.targetFrame(layout: .rightThird, visibleFrameAppKit: visible, gap: gap)
        // AX y differs by screen height; widths are origin-independent.
        let span = right.maxX - left.minX
        let expected = visible.width - gap * 2
        XCTAssertEqual(span, expected, accuracy: 2)
        XCTAssertLessThan(left.maxX, center.minX + 1)
        XCTAssertLessThan(center.maxX, right.minX + 1)
    }

    func testAXAppKitRoundTrip() {
        let primary: CGFloat = 1080
        let appKit = CGRect(x: 100, y: 50, width: 400, height: 300)
        let ax = LayoutGeometry.appKitToAX(appKit, primaryHeight: primary)
        let back = LayoutGeometry.axToAppKit(ax, primaryHeight: primary)
        XCTAssertEqual(back.origin.x, appKit.origin.x, accuracy: 0.01)
        XCTAssertEqual(back.origin.y, appKit.origin.y, accuracy: 0.01)
        XCTAssertEqual(back.width, appKit.width, accuracy: 0.01)
        XCTAssertEqual(back.height, appKit.height, accuracy: 0.01)
    }

    func testSnapLayoutRoundTrip() {
        for layout in allLayouts {
            let id = "window.snap.\(layout.rawValue)"
            XCTAssertEqual(ActionCatalog.snapLayout(for: id), layout, id)
        }
        XCTAssertNil(ActionCatalog.snapLayout(for: ActionCatalog.ID.minimize))
        XCTAssertNil(ActionCatalog.snapLayout(for: ActionCatalog.ID.none))
    }

    private var allLayouts: [WindowLayout] {
        [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf,
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .leftThird, .centerThird, .rightThird,
            .leftTwoThirds, .rightTwoThirds,
            .maximize, .center, .centerLarge, .almostMaximize,
        ]
    }
}

final class RestoreStoreTests: XCTestCase {
    func testFirstWriteWinsAndPopOnce() {
        let store = RestoreStore()
        let id = WindowIdentity(pid: 42, windowNumber: 7)
        store.remember(id, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        store.remember(id, frame: CGRect(x: 9, y: 9, width: 9, height: 9))
        XCTAssertEqual(store.restore(id), CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(store.restore(id))
    }

    func testSameTitleDifferentPidDoesNotCollide() {
        let store = RestoreStore()
        let a = WindowIdentity(pid: 1, windowNumber: 10)
        let b = WindowIdentity(pid: 2, windowNumber: 10)
        store.remember(a, frame: CGRect(x: 1, y: 1, width: 10, height: 10))
        store.remember(b, frame: CGRect(x: 2, y: 2, width: 20, height: 20))
        XCTAssertEqual(store.restore(a)?.width, 10)
        XCTAssertEqual(store.restore(b)?.width, 20)
    }

    func testSamePidDifferentWindowNumberDoesNotCollide() {
        let store = RestoreStore()
        let a = WindowIdentity(pid: 1, windowNumber: 10)
        let b = WindowIdentity(pid: 1, windowNumber: 11)
        store.remember(a, frame: CGRect(x: 1, y: 1, width: 10, height: 10))
        store.remember(b, frame: CGRect(x: 2, y: 2, width: 20, height: 20))
        XCTAssertEqual(store.restore(a)?.width, 10)
        XCTAssertEqual(store.restore(b)?.width, 20)
    }

    func testPeekDoesNotPop() {
        let store = RestoreStore()
        let id = WindowIdentity(pid: 1, windowNumber: 3)
        store.remember(id, frame: CGRect(x: 5, y: 5, width: 50, height: 50))
        XCTAssertEqual(store.peek(id)?.width, 50)
        XCTAssertEqual(store.peek(id)?.width, 50)
        XCTAssertEqual(store.restore(id)?.width, 50)
        XCTAssertNil(store.peek(id))
    }
}
