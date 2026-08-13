import XCTest
@testable import SanneKit

final class BindingResolverTests: XCTestCase {
    private let slotId = GestureSlots.ID.free3SwipeLeft
    private let safari = "com.apple.Safari"
    private let xcode = "com.apple.dt.Xcode"

    // MARK: - Precedence matrix

    func testDefaultWhenNoOverrides() {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true

        let resolved = BindingResolver.resolve(slotId: slotId, config: config)
        XCTAssertEqual(resolved?.enabled, true)
        XCTAssertEqual(resolved?.actionId, ActionCatalog.ID.browserForward)
        XCTAssertEqual(resolved?.isModified, false)
    }

    func testGlobalActionOverrideBeatsDefault() {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .global
        )

        let resolved = BindingResolver.resolve(slotId: slotId, config: config)
        XCTAssertEqual(resolved?.actionId, ActionCatalog.ID.missionControl)
        XCTAssertEqual(resolved?.enabled, true)
        XCTAssertEqual(resolved?.isModified, true)
    }

    func testAppActionOverrideBeatsGlobal() {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .global
        )
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.appExpose,
            scope: .app(bundleId: safari)
        )

        let withSafari = BindingResolver.resolve(
            slotId: slotId, config: config, frontmostBundleId: safari
        )
        XCTAssertEqual(withSafari?.actionId, ActionCatalog.ID.appExpose)

        let withXcode = BindingResolver.resolve(
            slotId: slotId, config: config, frontmostBundleId: xcode
        )
        XCTAssertEqual(withXcode?.actionId, ActionCatalog.ID.missionControl)
    }

    func testAppEnableCanReviveGloballyDisabledGesture() {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true
        config.setGestureOverride(
            slotId: slotId,
            enabled: false,
            actionId: nil,
            scope: .global
        )
        config.setGestureOverride(
            slotId: slotId,
            enabled: true,
            actionId: ActionCatalog.ID.browserForward,
            scope: .app(bundleId: safari)
        )

        let global = BindingResolver.resolve(slotId: slotId, config: config)
        XCTAssertEqual(global?.enabled, false)

        let app = BindingResolver.resolve(
            slotId: slotId, config: config, frontmostBundleId: safari
        )
        XCTAssertEqual(app?.enabled, true)
    }

    func testAppInheritsGlobalEnableWhenOnlyRemappingAction() {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true
        config.setGestureOverride(
            slotId: slotId,
            enabled: false,
            actionId: nil,
            scope: .global
        )
        // App only remaps action — must inherit global enabled=false (field-wise layering).
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .app(bundleId: safari)
        )

        let app = BindingResolver.resolve(
            slotId: slotId, config: config, frontmostBundleId: safari
        )
        XCTAssertEqual(app?.enabled, false)
        XCTAssertEqual(app?.actionId, ActionCatalog.ID.missionControl)
    }

    func testNilBundleIdSkipsAppLayer() {
        var config = SanneConfig()
        config.trackpad.threeFingerSwipes = true
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .global
        )
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.appExpose,
            scope: .app(bundleId: safari)
        )

        let nilFront = BindingResolver.resolve(
            slotId: slotId, config: config, frontmostBundleId: nil
        )
        XCTAssertEqual(nilFront?.actionId, ActionCatalog.ID.missionControl)
    }

    func testLegacyGateOffDisablesWhenNoExplicitEnable() {
        let config = SanneConfig()
        // threeFingerSwipes defaults to false
        XCTAssertFalse(config.trackpad.threeFingerSwipes)

        let resolved = BindingResolver.resolve(slotId: slotId, config: config)
        XCTAssertEqual(resolved?.enabled, false)
        XCTAssertEqual(resolved?.actionId, ActionCatalog.ID.browserForward)
    }

    func testMasterSwitchBeatsAllLayers() {
        var config = SanneConfig()
        config.magicMouseTaps.enabled = false
        config.magicMouseTaps.threeFingerSwipes = true
        config.setGestureOverride(
            slotId: GestureSlots.ID.mm3fSwipeLeft,
            enabled: true,
            actionId: ActionCatalog.ID.browserPrevTab,
            scope: .app(bundleId: safari)
        )

        let resolved = BindingResolver.resolve(
            slotId: GestureSlots.ID.mm3fSwipeLeft,
            config: config,
            frontmostBundleId: safari
        )
        XCTAssertEqual(resolved?.enabled, false)
        // Master-off returns the default action id, not the override.
        XCTAssertEqual(resolved?.actionId, ActionCatalog.ID.browserPrevTab)
    }

    // MARK: - setGestureOverride pruning

    func testPruningRemovesEmptyGlobalEntry() {
        var config = SanneConfig()
        config.setGestureOverride(
            slotId: slotId,
            enabled: true,
            actionId: ActionCatalog.ID.missionControl,
            scope: .global
        )
        XCTAssertNotNil(config.gestureOverrides[slotId])

        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: nil,
            scope: .global
        )
        XCTAssertNil(config.gestureOverrides[slotId])
    }

    func testPruningRemovesEmptyAppMap() {
        var config = SanneConfig()
        config.setGestureOverride(
            slotId: slotId,
            enabled: true,
            actionId: nil,
            scope: .app(bundleId: safari)
        )
        XCTAssertEqual(config.appGestureOverrides[safari]?.count, 1)

        config.clearGestureOverride(slotId: slotId, scope: .app(bundleId: safari))
        XCTAssertNil(config.appGestureOverrides[safari])
        XCTAssertFalse(config.appsWithGestureOverrides.contains(safari))
    }

    func testIsCustomizedScopeAware() {
        var config = SanneConfig()
        config.setGestureOverride(
            slotId: slotId,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .global
        )
        config.setGestureOverride(
            slotId: GestureSlots.ID.tipTapLeft,
            enabled: true,
            actionId: nil,
            scope: .app(bundleId: safari)
        )

        XCTAssertTrue(
            BindingResolver.isCustomized(slotId: slotId, config: config, scope: .global)
        )
        XCTAssertFalse(
            BindingResolver.isCustomized(
                slotId: slotId, config: config, scope: .app(bundleId: safari)
            )
        )
        XCTAssertTrue(
            BindingResolver.isCustomized(
                slotId: GestureSlots.ID.tipTapLeft,
                config: config,
                scope: .app(bundleId: safari)
            )
        )
    }

    func testMagicMouseDoubleTapHoldIsRemappable() {
        var config = SanneConfig()
        let slot = GestureSlots.slot(id: GestureSlots.ID.mmDrag)
        XCTAssertEqual(slot?.actionFixed, false)
        XCTAssertEqual(
            BindingResolver.resolve(slotId: GestureSlots.ID.mmDrag, config: config)?.actionId,
            ActionCatalog.ID.drag
        )

        config.setGestureOverride(
            slotId: GestureSlots.ID.mmDrag,
            enabled: nil,
            actionId: ActionCatalog.ID.missionControl,
            scope: .global
        )
        let remapped = BindingResolver.resolve(slotId: GestureSlots.ID.mmDrag, config: config)
        XCTAssertEqual(remapped?.actionId, ActionCatalog.ID.missionControl)
        XCTAssertEqual(remapped?.enabled, true)
        XCTAssertEqual(remapped?.isModified, true)
    }
}
