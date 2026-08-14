import XCTest
@testable import SanneKit

final class PresetTests: XCTestCase {
    func testStandardEnabledSetMatchesSlotDefaults() {
        for slot in GestureSlots.all {
            XCTAssertEqual(
                SannePreset.standard.enabledSlotIds.contains(slot.id),
                GestureSlots.defaultEnabled(for: slot.legacyGate),
                slot.id
            )
        }
    }

    func testMinimalEnablesOnlyTapsAndHalves() {
        let on = SannePreset.minimal.enabledSlotIds
        XCTAssertEqual(on, [
            GestureSlots.ID.mmLeft,
            GestureSlots.ID.mmRight,
            GestureSlots.ID.mmMiddle2,
            GestureSlots.ID.mmMiddle3,
            GestureSlots.ID.mmDrag,
            GestureSlots.ID.tbLeft,
            GestureSlots.ID.tbRight,
            GestureSlots.ID.tbUp,
            GestureSlots.ID.tbDown,
        ])
        XCTAssertFalse(on.contains(GestureSlots.ID.mm1fSwipeLeft))
        XCTAssertFalse(on.contains(GestureSlots.ID.free3Tap))
        XCTAssertFalse(on.contains(GestureSlots.ID.dockUp))
        XCTAssertFalse(on.contains(GestureSlots.ID.kbLeft))
    }

    func testApplyMinimalSetsMastersAndPresetId() {
        var config = SanneConfig()
        config.version = 2
        SannePreset.minimal.apply(to: &config, keepActionRemaps: true)

        XCTAssertEqual(config.presetId, SannePreset.minimalId)
        XCTAssertTrue(config.magicMouseTaps.enabled)
        XCTAssertTrue(config.titlebarGestures.enabled)
        XCTAssertFalse(config.dockGestures.enabled)
        XCTAssertFalse(config.menubarGestures.enabled)
        XCTAssertFalse(config.keyboard.enabled)
        XCTAssertEqual(SannePreset.matching(config)?.id, SannePreset.minimalId)
    }

    func testApplyKeepsActionRemaps() {
        var config = SanneConfig()
        config.version = 2
        config.setGestureOverride(
            slotId: GestureSlots.ID.mmLeft,
            enabled: nil,
            actionId: ActionCatalog.ID.close,
            scope: .global
        )
        SannePreset.minimal.apply(to: &config, keepActionRemaps: true)

        XCTAssertEqual(
            config.gestureOverrides[GestureSlots.ID.mmLeft]?.actionId,
            ActionCatalog.ID.close
        )
        XCTAssertNil(config.gestureOverrides[GestureSlots.ID.mmLeft]?.enabled)
        XCTAssertTrue(SannePreset.hasActionRemaps(config))
    }

    func testApplyCanClearActionRemaps() {
        var config = SanneConfig()
        config.version = 2
        config.setGestureOverride(
            slotId: GestureSlots.ID.mmLeft,
            enabled: nil,
            actionId: ActionCatalog.ID.close,
            scope: .global
        )
        config.setGestureOverride(
            slotId: GestureSlots.ID.free3Tap,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .app(bundleId: "com.apple.Safari")
        )
        SannePreset.standard.apply(to: &config, keepActionRemaps: false)

        XCTAssertTrue(config.gestureOverrides.isEmpty)
        XCTAssertTrue(config.appGestureOverrides.isEmpty)
        XCTAssertFalse(SannePreset.hasActionRemaps(config))
    }

    func testResolverUsesMinimalDefaultsOnV2() {
        var config = SanneConfig()
        config.version = 2
        SannePreset.minimal.apply(to: &config, keepActionRemaps: true)

        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.mmLeft, config: config)?.enabled,
            true
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.mm1fSwipeLeft, config: config)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.tbLeft, config: config)?.enabled,
            true
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.tbLeftLong, config: config)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.dockUp, config: config)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.free3Tap, config: config)?.enabled,
            false
        )
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.kbLeft, config: config)?.enabled,
            false
        )
    }

    func testEnablementDriftBecomesCustom() {
        var config = SanneConfig()
        config.version = 2
        SannePreset.minimal.apply(to: &config, keepActionRemaps: true)
        XCTAssertEqual(SannePreset.matching(config)?.id, SannePreset.minimalId)

        config.setGestureOverride(
            slotId: GestureSlots.ID.mm1fSwipeLeft,
            enabled: true,
            actionId: nil,
            scope: .global
        )
        XCTAssertNil(SannePreset.matching(config), "extra enablement is Custom")
    }

    func testDefaultConfigMatchesStandard() {
        var config = SanneConfig()
        config.version = 2
        config.presetId = SannePreset.standardId
        XCTAssertEqual(SannePreset.matching(config)?.id, SannePreset.standardId)
    }
}
