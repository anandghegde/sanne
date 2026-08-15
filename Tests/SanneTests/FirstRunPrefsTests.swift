import XCTest
@testable import SanneKit

final class FirstRunPrefsTests: XCTestCase {
    func testDayOneSimpleSlotsStaySmall() {
        let simple = GestureSlots.all.filter { $0.visibility == .simple }
        let mm = simple.filter { $0.group == .magicMouse }
        XCTAssertEqual(mm.count, 8) // L/R tap, 1F pages, 3F middle, tap-drag, tip-tap L/R
        XCTAssertEqual(simple.filter { $0.group == .trackpad }.count, 4)
        XCTAssertEqual(simple.filter { $0.group == .keyboard }.count, 7)
        XCTAssertLessThan(simple.filter { $0.group != .keyboard }.count, 25)
    }

    func testWelcomeShowsUntilCompleted() {
        XCTAssertTrue(WelcomePrefs.shouldShowOnboarding(hasCompletedWelcome: false))
        XCTAssertFalse(WelcomePrefs.shouldShowOnboarding(hasCompletedWelcome: true))
    }

    func testTutorialOfferIsOneShotAfterWelcome() {
        XCTAssertTrue(
            WelcomePrefs.shouldOfferTutorial(
                hasCompletedWelcome: true,
                tutorialCompleted: false,
                offerDismissed: false
            )
        )
        XCTAssertFalse(
            WelcomePrefs.shouldOfferTutorial(
                hasCompletedWelcome: false,
                tutorialCompleted: false,
                offerDismissed: false
            ),
            "Welcome still open — do not also offer from Home"
        )
        XCTAssertFalse(
            WelcomePrefs.shouldOfferTutorial(
                hasCompletedWelcome: true,
                tutorialCompleted: true,
                offerDismissed: false
            )
        )
        XCTAssertFalse(
            WelcomePrefs.shouldOfferTutorial(
                hasCompletedWelcome: true,
                tutorialCompleted: false,
                offerDismissed: true
            )
        )
    }

    func testAdoptExistingInstallWritesTrueOnlyWhenKeyMissing() {
        let suite = "sanne.tests.welcome.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        WelcomePrefs.adoptExistingInstall(defaults: defaults)
        XCTAssertEqual(defaults.object(forKey: WelcomePrefs.completedKey) as? Bool, true)

        defaults.set(false, forKey: WelcomePrefs.completedKey)
        WelcomePrefs.adoptExistingInstall(defaults: defaults)
        XCTAssertEqual(defaults.object(forKey: WelcomePrefs.completedKey) as? Bool, false)

        defaults.removePersistentDomain(forName: suite)
    }

    func testMarkFreshInstallWritesFalseOnlyWhenKeyMissing() {
        let suite = "sanne.tests.welcome.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        WelcomePrefs.markFreshInstall(defaults: defaults)
        XCTAssertEqual(defaults.object(forKey: WelcomePrefs.completedKey) as? Bool, false)

        defaults.set(true, forKey: WelcomePrefs.completedKey)
        WelcomePrefs.markFreshInstall(defaults: defaults)
        XCTAssertEqual(defaults.object(forKey: WelcomePrefs.completedKey) as? Bool, true)

        defaults.removePersistentDomain(forName: suite)
    }
}
