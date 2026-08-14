import XCTest
@testable import SanneKit

/// IMPROVEMENT_PLAN §5.1 remaining rows: migrate, emit matrix, bundled Standard.
final class Phase5QualityTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - 7. 0.2.0 JSON → slot-only enablement

    func testVersion020FixtureMigratesEverySlotUnchanged() throws {
        let json = """
        {
          "version": 1,
          "presetId": "sanne.standard",
          "paused": false,
          "magicMouseTaps": {
            "enabled": true,
            "leftTap": true,
            "rightTap": false,
            "middleTwoFinger": true,
            "middleThreeFinger": true,
            "tapDrag": true,
            "multiClick": true,
            "twoFingerDoubleTapMissionControl": false,
            "twoFingerSwipeUpMissionControl": true,
            "twoFingerSwipeDownAppExpose": true,
            "twoFingerSwipeSpaces": false,
            "threeFingerSwipes": false,
            "twoFingerTopEdgeMove": true,
            "oneFingerSwipePages": true
          },
          "titlebarGestures": {
            "enabled": true,
            "swipeHalves": true,
            "swipeQuarters": false,
            "swipeThirds": true,
            "swipeMaximize": true,
            "swipeMinimize": true,
            "pinchClose": true,
            "pinchFullscreen": true,
            "threeFingerMoveDisplay": false
          },
          "dockGestures": { "enabled": true, "pinchQuit": false },
          "menubarGestures": { "enabled": true },
          "trackpad": {
            "threeFingerTapMiddleClick": true,
            "threeFingerDrag": true,
            "threeFingerSwipes": false,
            "fourFingerSwipes": false,
            "fourFingerTap": false,
            "tipTap": false
          },
          "keyboard": { "enabled": true, "snapWithArrows": true, "moveToAdjacentDisplay": true },
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
          "hud": { "enabled": true }
        }
        """
        let config = try decoder.decode(SanneConfig.self, from: Data(json.utf8))
        var migrated = config
        migrated.migrateToSlotEnablement()
        XCTAssertEqual(migrated.version, 2)

        for slot in GestureSlots.all {
            let before = GestureSlots.legacyEnabled(slot.legacyGate, config: config)
            let after = BindingResolver.resolve(slotId: slot.id, config: migrated)?.enabled
            XCTAssertEqual(after, before, "\(slot.id) enablement must survive migrate")
        }

        XCTAssertEqual(
            migrated.gestureOverrides[GestureSlots.ID.free3Tap]?.actionId,
            ActionCatalog.ID.close
        )
        XCTAssertEqual(
            migrated.appGestureOverrides["com.apple.Safari"]?[GestureSlots.ID.free3Tap]?.actionId,
            ActionCatalog.ID.browserCloseTab
        )
        XCTAssertEqual(migrated.customActions.count, 1)
        XCTAssertTrue(migrated.hud.enabled)
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.mmRight, config: migrated)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.tbUpLeft, config: migrated)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.tb3Left, config: migrated)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.mm2fDoubleMC, config: migrated)?.enabled,
            false
        )
    }

    // MARK: - 8. BindingResolver + emit matrix

    func testEmitMatrixMatchesResolverForEverySlot() {
        var config = SanneConfig()
        config.version = 2
        config.presetId = SannePreset.standardId

        for slot in GestureSlots.all {
            let resolved = BindingResolver.resolve(slotId: slot.id, config: config)
            XCTAssertEqual(
                LegacyRecognition.wouldEmit(slotId: slot.id, config: config),
                resolved?.enabled ?? false,
                "default emit \(slot.id)"
            )
            XCTAssertEqual(
                resolved?.enabled,
                SannePreset.defaultEnabled(for: slot, presetId: SannePreset.standardId),
                "default enabled \(slot.id)"
            )
        }

        config.magicMouseTaps.enabled = false
        XCTAssertFalse(LegacyRecognition.wouldEmit(slotId: GestureSlots.ID.mmLeft, config: config))
        XCTAssertFalse(LegacyRecognition.wouldEmit(slotId: GestureSlots.ID.mm3fTopEdgeResize, config: config))

        config.magicMouseTaps.enabled = true
        config.setGestureOverride(
            slotId: GestureSlots.ID.mm3fSwipeLeft,
            enabled: true,
            actionId: nil,
            scope: .global
        )
        XCTAssertTrue(LegacyRecognition.wouldEmit(slotId: GestureSlots.ID.mm3fSwipeLeft, config: config))

        config.setGestureOverride(
            slotId: GestureSlots.ID.mmLeft,
            enabled: false,
            actionId: nil,
            scope: .global
        )
        XCTAssertFalse(LegacyRecognition.wouldEmit(slotId: GestureSlots.ID.mmLeft, config: config))
    }

    // MARK: - 10. Bundled sanne.standard.json == GestureSlots defaults

    func testBundledStandardJSONMatchesGestureSlotsDefaults() throws {
        guard var bundled = BundledPreset.loadStandard() else {
            XCTFail("sanne.standard.json missing from SanneKit bundle")
            return
        }
        if bundled.version < 2 {
            bundled.migrateToSlotEnablement()
        }
        XCTAssertEqual(bundled.presetId, SannePreset.standardId)
        for slot in GestureSlots.all {
            XCTAssertEqual(
                BindingResolver.resolve(slotId: slot.id, config: bundled)?.enabled,
                GestureSlots.defaultEnabled(for: slot.legacyGate),
                "bundled Standard drifted for \(slot.id)"
            )
        }
    }
}

final class ContinuousThirdsTests: XCTestCase {
    func testMagnitudeBands() {
        XCTAssertEqual(LayoutGeometry.continuousLeftLayout(magnitude: 0.10), .leftHalf)
        XCTAssertEqual(LayoutGeometry.continuousLeftLayout(magnitude: 0.21), .leftHalf)
        XCTAssertEqual(LayoutGeometry.continuousLeftLayout(magnitude: 0.22), .leftThird)
        XCTAssertEqual(LayoutGeometry.continuousLeftLayout(magnitude: 0.43), .leftThird)
        XCTAssertEqual(LayoutGeometry.continuousLeftLayout(magnitude: 0.44), .leftTwoThirds)
        XCTAssertEqual(LayoutGeometry.continuousRightLayout(magnitude: 0.10), .rightHalf)
        XCTAssertEqual(LayoutGeometry.continuousRightLayout(magnitude: 0.30), .rightThird)
        XCTAssertEqual(LayoutGeometry.continuousRightLayout(magnitude: 0.50), .rightTwoThirds)
    }

    func testCycleThirdsKeepsShortSlot() {
        XCTAssertEqual(
            GestureSlots.titlebarSwipeSlot(fingers: 2, direction: .left, magnitude: 0.40, cycleThirds: true),
            GestureSlots.ID.tbLeft
        )
        XCTAssertEqual(
            GestureSlots.titlebarSwipeSlot(fingers: 2, direction: .left, magnitude: 0.40, cycleThirds: false),
            GestureSlots.ID.tbLeftLong
        )
    }
}

final class SpaceMoverTests: XCTestCase {
    func testNeighborSkipsFullscreenAndEdges() {
        let spaces: [[String: Any]] = [
            [
                "Current Space": ["id64": 2],
                "Spaces": [
                    ["id64": 1, "type": 0],
                    ["id64": 2, "type": 0],
                    ["id64": 99, "type": 4],
                    ["id64": 3, "type": 0],
                ],
            ]
        ]
        XCTAssertEqual(SpaceMover.neighborSpaceID(in: spaces, direction: 1), 3)
        XCTAssertEqual(SpaceMover.neighborSpaceID(in: spaces, direction: -1), 1)

        let atEdge: [[String: Any]] = [
            [
                "Current Space": ["id64": 1],
                "Spaces": [["id64": 1, "type": 0]],
            ]
        ]
        XCTAssertNil(SpaceMover.neighborSpaceID(in: atEdge, direction: 1))
        XCTAssertEqual(SpaceMover.hudTitle(for: .disabled), "Spaces move is off")
        XCTAssertEqual(SpaceMover.hudTitle(for: .apiUnavailable), "Can't move Space")
    }
}

final class UpdateCheckerTests: XCTestCase {
    func testVersionCompare() {
        XCTAssertTrue(UpdateChecker.isNewer("0.3.0", than: "0.2.0"))
        XCTAssertTrue(UpdateChecker.isNewer("v1.0.0", than: "0.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.2.0", than: "0.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.9", than: "0.2.0"))
    }

    func testParseAndEvaluate() throws {
        let json = """
        { "tag_name": "v0.3.0", "html_url": "https://github.com/anandghegde/sanne/releases/tag/v0.3.0" }
        """
        let release = UpdateChecker.parseLatest(from: Data(json.utf8))
        XCTAssertEqual(release?.tag, "v0.3.0")
        XCTAssertEqual(
            UpdateChecker.evaluate(latest: release!, current: "0.2.0"),
            .available(release!)
        )
        XCTAssertEqual(
            UpdateChecker.evaluate(latest: release!, current: "0.3.0"),
            .upToDate(current: "0.3.0")
        )
    }
}

final class GamingModeTests: XCTestCase {
    func testOnlyRightHoldPlusLeftZone() {
        XCTAssertTrue(MMGeometry.gamingLeftTap(gamingMode: true, rightHeld: true, zone: .left))
        XCTAssertFalse(MMGeometry.gamingLeftTap(gamingMode: true, rightHeld: true, zone: .right))
        XCTAssertFalse(MMGeometry.gamingLeftTap(gamingMode: true, rightHeld: false, zone: .left))
        XCTAssertFalse(MMGeometry.gamingLeftTap(gamingMode: false, rightHeld: true, zone: .left))
        XCTAssertFalse(MMGeometry.gamingLeftTap(gamingMode: true, rightHeld: true, zone: .dead))
    }
}

final class SafeModeTests: XCTestCase {
    func testForceFlag() {
        SafeMode.force = true
        XCTAssertTrue(SafeMode.isActive)
        SafeMode.force = false
        XCTAssertFalse(SafeMode.isActive)
        SafeMode.force = nil
    }
}
