import XCTest
@testable import SanneKit

final class SettingsSearchTests: XCTestCase {
    func testLaunchAtLoginResolves() {
        let hits = SettingsSearch.hits(query: "launch at login")
        XCTAssertTrue(hits.contains { $0.title == "Launch at login" })
        XCTAssertEqual(hits.first { $0.title == "Launch at login" }?.route, PreferencesRoute.about)
    }

    func testHapticsResolves() {
        let hits = SettingsSearch.hits(query: "haptics")
        XCTAssertTrue(hits.contains { $0.title == "Haptic feedback" })
        XCTAssertEqual(hits.first { $0.title == "Haptic feedback" }?.route, PreferencesRoute.home)
    }

    func testGapResolves() {
        let hits = SettingsSearch.hits(query: "gap")
        XCTAssertTrue(hits.contains { $0.title == "Gap" })
        XCTAssertEqual(hits.first { $0.title == "Gap" }?.route, PreferencesRoute.windows)
    }

    func testHUDResolves() {
        let hits = SettingsSearch.hits(query: "HUD")
        XCTAssertTrue(hits.contains { $0.title == "Action name overlay" })
        XCTAssertEqual(hits.first { $0.title == "Action name overlay" }?.route, PreferencesRoute.home)
    }

    func testInputMonitoringAndDeadZoneResolve() {
        let permissionHits = SettingsSearch.hits(query: "input monitoring")
        XCTAssertEqual(permissionHits.first { $0.title == "Input Monitoring" }?.route, PreferencesRoute.keyboard)

        let tuningHits = SettingsSearch.hits(query: "dead zone")
        XCTAssertEqual(tuningHits.first { $0.title == "Dead zone" }?.route, PreferencesRoute.magicMouse)
    }

    func testSlotTitleResolves() {
        let hits = SettingsSearch.hits(query: "Tap left")
        XCTAssertTrue(hits.contains { $0.slotId == GestureSlots.ID.mmLeft })
    }

    func testMagicMouseTipTapResolves() {
        let hits = SettingsSearch.hits(query: "tip-tap")
        XCTAssertTrue(hits.contains { $0.slotId == GestureSlots.ID.mmTipTapLeft })
        XCTAssertTrue(hits.contains { $0.slotId == GestureSlots.ID.mmTipTapRight })
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(SettingsSearch.hits(query: "   ").isEmpty)
    }
}
