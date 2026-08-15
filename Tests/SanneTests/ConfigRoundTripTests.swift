import XCTest
@testable import SanneKit

final class ConfigRoundTripTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    func testVersion020FixtureLoadsWithLegacyBoolsAndOverrides() throws {
        let json = """
        {
          "version": 1,
          "presetId": "sanne.standard",
          "paused": false,
          "magicMouseTaps": {
            "enabled": true,
            "leftTap": true,
            "rightTap": false,
            "threeFingerSwipes": false
          },
          "titlebarGestures": { "enabled": true, "swipeHalves": true },
          "gestureOverrides": {
            "trackpad.free.3.tap": { "actionId": "window.close" }
          },
          "appGestureOverrides": {
            "com.apple.Safari": {
              "trackpad.free.3.tap": { "actionId": "browser.closeTab" }
            }
          },
          "customActions": [
            {
              "id": "00000000-0000-0000-0000-000000000099",
              "name": "Hello",
              "kind": "shell",
              "payload": "echo hi"
            }
          ],
          "hud": { "enabled": true },
          "launchAtLogin": false
        }
        """
        let config = try decoder.decode(SanneConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.version, 1)
        XCTAssertTrue(config.magicMouseTaps.leftTap)
        XCTAssertFalse(config.magicMouseTaps.rightTap)
        XCTAssertEqual(
            config.gestureOverrides[GestureSlots.ID.free3Tap]?.actionId,
            ActionCatalog.ID.close
        )
        XCTAssertEqual(
            config.appGestureOverrides["com.apple.Safari"]?[GestureSlots.ID.free3Tap]?.actionId,
            ActionCatalog.ID.browserCloseTab
        )
        XCTAssertEqual(config.customActions.count, 1)
        XCTAssertTrue(config.hud.enabled)

        var migrated = config
        migrated.migrateToSlotEnablement()
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(
            migrated.gestureOverrides[GestureSlots.ID.mmRight]?.enabled,
            false,
            "rightTap was off in 0.2.0 and must stay off after migrate"
        )
        XCTAssertEqual(
            migrated.gestureOverrides[GestureSlots.ID.free3Tap]?.actionId,
            ActionCatalog.ID.close,
            "existing remaps survive migrate"
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.mmLeft, config: migrated)?.enabled,
            true
        )
        XCTAssertEqual(migrated.customActions.count, 1)
        XCTAssertTrue(migrated.hud.enabled)
    }

    func testBundledStandardSlotDefaultsMatchCode() throws {
        for slot in GestureSlots.all {
            XCTAssertEqual(
                slot.defaultEnabled,
                GestureSlots.defaultEnabled(for: slot.legacyGate),
                "\(slot.id) defaultEnabled drifted from Sanne Standard"
            )
        }
    }

    func testEmptyJSONYieldsDefaults() throws {
        let config = try decoder.decode(SanneConfig.self, from: Data("{}".utf8))

        XCTAssertEqual(config.version, 1)
        XCTAssertFalse(config.trackpad.threeFingerSwipes)
        XCTAssertFalse(config.trackpad.fourFingerSwipes)
        XCTAssertFalse(config.trackpad.fourFingerTap)
        XCTAssertTrue(config.trackpad.tipTap)
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
        XCTAssertTrue(config.trackpad.tipTap)
        XCTAssertFalse(config.magicMouseTaps.threeFingerSwipes)
        XCTAssertTrue(config.trackpad.threeFingerDrag)
        XCTAssertTrue(config.hud.enabled)
        XCTAssertEqual(config.customActions, [])
        XCTAssertEqual(config.appGestureOverrides, [:])
    }

    func testFullConfigRoundTrip() throws {
        var config = SanneConfig()
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

    func testPartialDockJSONKeepsOtherDockFlags() throws {
        let json = """
        { "dockGestures": { "enabled": false } }
        """
        let config = try decoder.decode(SanneConfig.self, from: Data(json.utf8))
        XCTAssertFalse(config.dockGestures.enabled)
        XCTAssertTrue(config.dockGestures.swipeActivate)
        XCTAssertTrue(config.dockGestures.swipeHide)
        XCTAssertTrue(config.dockGestures.pinchNewWindow)
        XCTAssertFalse(config.dockGestures.pinchQuit)
    }

    func testPartialMenubarJSONKeepsOtherMenubarFlags() throws {
        let json = """
        { "menubarGestures": { "swipeHideOthers": false } }
        """
        let config = try decoder.decode(SanneConfig.self, from: Data(json.utf8))
        XCTAssertTrue(config.menubarGestures.enabled)
        XCTAssertTrue(config.menubarGestures.swipeCycleWindows)
        XCTAssertFalse(config.menubarGestures.swipeHideOthers)
        XCTAssertTrue(config.menubarGestures.swipeUnminimize)
    }

    func testAppOverrideDecodesLegacyDisabledKeyAsIsActive() throws {
        let json = """
        { "bundleId": "com.apple.Safari", "displayName": "Safari", "disabled": true }
        """
        let override = try decoder.decode(AppOverride.self, from: Data(json.utf8))
        XCTAssertTrue(override.isActive)

        let off = """
        { "bundleId": "com.apple.Safari", "disabled": false }
        """
        let inactive = try decoder.decode(AppOverride.self, from: Data(off.utf8))
        XCTAssertFalse(inactive.isActive)
    }

    func testAppOverrideEncodesIsActiveNotDisabled() throws {
        let override = AppOverride(bundleId: "com.apple.Safari", displayName: "Safari", isActive: true)
        let data = try encoder.encode(override)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(object["isActive"] as? Bool, true)
        XCTAssertNil(object["disabled"])
    }

    func testCorruptConfigBackupPreservesOriginalBytes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sanne-config-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("config.json")
        let original = Data("{ not json".utf8)
        let bak = try ConfigFileRecovery.writeBackup(data: original, fileURL: file)
        XCTAssertEqual(bak, file.appendingPathExtension("bak"))
        XCTAssertEqual(try Data(contentsOf: bak), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
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

    func testNewEncodeOmitsDeletedLegacyKeys() throws {
        let config = SanneConfig()
        let data = try encoder.encode(config)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let mm = object["magicMouseTaps"] as? [String: Any]
        XCTAssertNil(mm?["leftTap"])
        XCTAssertNil(mm?["rightTap"])
        XCTAssertNotNil(mm?["multiClick"])
        let tp = object["trackpad"] as? [String: Any]
        XCTAssertNil(tp?["threeFingerSwipes"])
        XCTAssertNotNil(tp?["sensitivity"])
    }
}
