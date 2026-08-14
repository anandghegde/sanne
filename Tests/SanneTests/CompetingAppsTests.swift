import XCTest
@testable import SanneKit

final class CompetingAppsTests: XCTestCase {
    func testMultitouchBundleId() {
        XCTAssertEqual(
            CompetingApps.match(bundleId: "com.brassmonkery.Multitouch", localizedName: "Multitouch"),
            "Multitouch"
        )
    }

    func testTapToClickBundleId() {
        XCTAssertEqual(
            CompetingApps.match(bundleId: "com.larabr.taptoclick", localizedName: "TapToClick"),
            "TapToClick"
        )
    }

    func testMiddleNameIsNotAConflict() {
        XCTAssertNil(CompetingApps.match(bundleId: "com.example.Middle", localizedName: "Middle"))
    }

    func testNameFallbackStillFindsMultitouch() {
        XCTAssertEqual(
            CompetingApps.match(bundleId: "com.unknown.mt", localizedName: "Multitouch"),
            "Multitouch"
        )
    }

    func testUnknownAppIsNotAConflict() {
        XCTAssertNil(CompetingApps.match(bundleId: "com.apple.Safari", localizedName: "Safari"))
    }
}
