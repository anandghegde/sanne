import XCTest
@testable import SanneKit

final class ActionCatalogTests: XCTestCase {
    func testCustomActionIdRoundTrip() {
        let id = UUID()
        let actionId = ActionCatalog.customActionId(id)
        XCTAssertEqual(ActionCatalog.parseCustomAction(actionId), id)
        XCTAssertTrue(actionId.hasPrefix("action.custom."))
    }

    func testParseCustomActionRejectsUnknown() {
        XCTAssertNil(ActionCatalog.parseCustomAction("action.custom.not-a-uuid"))
        XCTAssertNil(ActionCatalog.parseCustomAction("window.snap.maximize"))
        XCTAssertNil(ActionCatalog.parseCustomAction(""))
    }

    func testUnknownUUIDResolvesToNil() {
        ActionCatalog.syncCustomActions([])
        let missing = UUID()
        XCTAssertNil(ActionCatalog.customAction(id: missing))
    }

    func testSyncCustomActionsLookup() {
        let id = UUID()
        let def = CustomActionDef(id: id, name: "Ping", kind: .shell, payload: "echo ping")
        ActionCatalog.syncCustomActions([def])
        defer { ActionCatalog.syncCustomActions([]) }

        XCTAssertEqual(ActionCatalog.customAction(id: id)?.name, "Ping")
        XCTAssertEqual(ActionCatalog.title(for: ActionCatalog.customActionId(id)), "Ping")
    }

    func testAnnouncesInHUDAllowList() {
        // Silent on purpose.
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.none))
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.drag))
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.moveWindow))
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.clickLeft))
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.clickRight))
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.clickMiddle))

        // Announced.
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.ID.missionControl))
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.ID.snapMaximize))
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.ID.browserPrevTab))
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.ID.keySpotlight))
        XCTAssertTrue(
            ActionCatalog.announcesInHUD(ActionCatalog.customActionId(UUID()))
        )
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.ID.restore))
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.launchAppId(bundleId: "com.apple.Safari")))
        XCTAssertEqual(ActionCatalog.hudTitle(for: ActionCatalog.ID.restore), "Restore")
        XCTAssertTrue(ActionCatalog.hudTitle(for: ActionCatalog.launchAppId(bundleId: "com.apple.Safari")).hasPrefix("Running "))
    }

    func testRestoreIsInCatalog() {
        XCTAssertTrue(ActionCatalog.all.contains { $0.id == ActionCatalog.ID.restore })
        XCTAssertEqual(ActionCatalog.title(for: ActionCatalog.ID.restore), "Restore")
        XCTAssertNil(ActionCatalog.snapLayout(for: ActionCatalog.ID.restore))
    }

    func testSpaceAndResizeActionsAreInCatalog() {
        XCTAssertTrue(ActionCatalog.all.contains { $0.id == ActionCatalog.ID.moveSpaceLeft })
        XCTAssertTrue(ActionCatalog.all.contains { $0.id == ActionCatalog.ID.moveSpaceRight })
        XCTAssertTrue(ActionCatalog.all.contains { $0.id == ActionCatalog.ID.resizeWindow })
        XCTAssertFalse(ActionCatalog.announcesInHUD(ActionCatalog.ID.resizeWindow))
        XCTAssertTrue(ActionCatalog.announcesInHUD(ActionCatalog.ID.moveSpaceLeft))
        XCTAssertEqual(
            ActionCatalog.actionId(for: .leftTwoThirds),
            ActionCatalog.ID.snapLeftTwoThirds
        )
    }

    func testKeyboardSlotsDefaultToRestoreOnDown() {
        let down = GestureSlots.slot(id: GestureSlots.ID.kbDown)
        XCTAssertEqual(down?.defaultActionId, ActionCatalog.ID.restore)
        XCTAssertEqual(down?.group, .keyboard)
    }

    func testCustomActionLimitsMatchDocumentedDefaults() {
        XCTAssertEqual(CustomActionLimits.timeoutSeconds, 10)
        XCTAssertEqual(CustomActionLimits.concurrentScripts, 4)
    }
}
