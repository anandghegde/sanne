import XCTest
@testable import SanneKit

final class ConfigRoundTripTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    func testEmptyJSONYieldsDefaults() throws {
        let config = try decoder.decode(SanneConfig.self, from: Data("{}".utf8))

        XCTAssertEqual(config.version, 1)
        XCTAssertFalse(config.trackpad.threeFingerSwipes)
        XCTAssertFalse(config.trackpad.fourFingerSwipes)
        XCTAssertFalse(config.trackpad.fourFingerTap)
        XCTAssertFalse(config.trackpad.tipTap)
        XCTAssertFalse(config.magicMouseTaps.threeFingerSwipes)
        XCTAssertTrue(config.trackpad.threeFingerTapMiddleClick)
        XCTAssertTrue(config.trackpad.threeFingerDrag)
        XCTAssertTrue(config.hud.enabled)
        XCTAssertTrue(config.customActions.isEmpty)
        XCTAssertTrue(config.appGestureOverrides.isEmpty)
    }

    func testPreChangeConfigLeavesNewFieldsAtDefault() throws {
        // Shape of a config written before steps 1–6 landed: no free-space / tip-tap /
        // customActions / appGestureOverrides / hud keys.
        let legacy = """
        {
          "version": 1,
          "presetId": "sanne.standard",
          "paused": false,
          "trackpad": {
            "threeFingerTapMiddleClick": true,
            "threeFingerDrag": true,
            "sensitivity": 0
          },
          "gestureOverrides": {},
          "launchAtLogin": false
        }
        """
        let config = try decoder.decode(SanneConfig.self, from: Data(legacy.utf8))

        XCTAssertFalse(config.trackpad.threeFingerSwipes)
        XCTAssertFalse(config.trackpad.fourFingerSwipes)
        XCTAssertFalse(config.trackpad.fourFingerTap)
        XCTAssertFalse(config.trackpad.tipTap)
        XCTAssertFalse(config.magicMouseTaps.threeFingerSwipes)
        XCTAssertTrue(config.trackpad.threeFingerDrag)
        XCTAssertTrue(config.hud.enabled)
        XCTAssertEqual(config.customActions, [])
        XCTAssertEqual(config.appGestureOverrides, [:])
    }

    func testFullConfigRoundTrip() throws {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true
        config.trackpad.fourFingerSwipes = true
        config.trackpad.fourFingerTap = true
        config.trackpad.tipTap = true
        config.magicMouseTaps.threeFingerSwipes = true
        config.hud.enabled = false

        let scriptId = UUID()
        config.customActions = [
            CustomActionDef(
                id: scriptId,
                name: "Say hi",
                kind: .shell,
                payload: "echo hello"
            )
        ]
        config.setGestureOverride(
            slotId: GestureSlots.ID.free3SwipeLeft,
            enabled: true,
            actionId: ActionCatalog.customActionId(scriptId),
            scope: .global
        )
        config.setGestureOverride(
            slotId: GestureSlots.ID.tipTapLeft,
            enabled: nil,
            actionId: ActionCatalog.ID.browserPrevTab,
            scope: .app(bundleId: "com.apple.Safari")
        )

        let data = try encoder.encode(config)
        let decoded = try decoder.decode(SanneConfig.self, from: data)

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.customActions.first?.payload, "echo hello")
        XCTAssertEqual(
            decoded.appGestureOverrides["com.apple.Safari"]?[GestureSlots.ID.tipTapLeft]?.actionId,
            ActionCatalog.ID.browserPrevTab
        )
    }

    func testCustomActionTolerantDecode() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Partial"
        }
        """
        let def = try decoder.decode(CustomActionDef.self, from: Data(json.utf8))
        XCTAssertEqual(def.kind, .shell)
        XCTAssertEqual(def.payload, "")
        XCTAssertFalse(def.isRunnable)
        XCTAssertEqual(def.displayName, "Partial")
    }

    func testRemoveCustomActionClearsGlobalAndAppOverrides() {
        var config = SanneConfig()
        let id = UUID()
        config.customActions = [
            CustomActionDef(id: id, name: "x", kind: .shell, payload: "true")
        ]
        let actionId = ActionCatalog.customActionId(id)
        config.setGestureOverride(
            slotId: GestureSlots.ID.free3SwipeLeft,
            enabled: true,
            actionId: actionId,
            scope: .global
        )
        config.setGestureOverride(
            slotId: GestureSlots.ID.tipTapRight,
            enabled: nil,
            actionId: actionId,
            scope: .app(bundleId: "com.apple.Safari")
        )

        config.removeCustomAction(id: id)

        XCTAssertTrue(config.customActions.isEmpty)
        // Global still has an enable-only override (enabled was true); only the dead action id
        // is blanked so the slot falls back to its Sanne Standard default.
        XCTAssertEqual(
            config.gestureOverrides[GestureSlots.ID.free3SwipeLeft],
            GestureOverrideEntry(enabled: true, actionId: nil)
        )
        // App entry stored only the action id, so pruning drops the whole app map.
        XCTAssertNil(config.appGestureOverrides["com.apple.Safari"])
    }

    func testGestureOverrideEntryLayering() {
        let base = GestureOverrideEntry(enabled: false, actionId: ActionCatalog.ID.missionControl)
        let top = GestureOverrideEntry(enabled: nil, actionId: ActionCatalog.ID.appExpose)
        let layered = top.layered(over: base)
        XCTAssertEqual(layered.enabled, false)
        XCTAssertEqual(layered.actionId, ActionCatalog.ID.appExpose)

        let emptyOverNil = GestureOverrideEntry().layered(over: nil)
        XCTAssertTrue(emptyOverNil.isEmpty)
    }
}
