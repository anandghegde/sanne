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
    }

    func testCustomActionLimitsMatchDocumentedDefaults() {
        XCTAssertEqual(CustomActionLimits.timeoutSeconds, 10)
        XCTAssertEqual(CustomActionLimits.concurrentScripts, 4)
    }
}
