import Foundation

// MARK: - Tutorial progress signals

enum TutorialSignal: String {
    case magicMouseClick
    case titlebarSnap
    case trackpadMiddleClick
    case dockActivate
}

extension Notification.Name {
    static let sanneTutorialSignal = Notification.Name("sanneTutorialSignal")
    static let sanneShowTutorial = Notification.Name("sanneShowTutorial")
    static let sanneShowCheatSheet = Notification.Name("sanneShowCheatSheet")
    static let sanneShowPreferences = Notification.Name("sanneShowPreferences")
}

enum TutorialPrefs {
    static let completedKey = "sanne.tutorialCompleted"

    static var completed: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static func post(_ signal: TutorialSignal) {
        NotificationCenter.default.post(
            name: .sanneTutorialSignal,
            object: nil,
            userInfo: ["signal": signal.rawValue]
        )
    }
}

/// First-run welcome + one-shot Home tutorial offer. Separate from `TutorialPrefs.completed`
/// so skipping the welcome still offers the tour once, and completing the tour never repeats it.
enum WelcomePrefs {
    static let completedKey = "sanne.hasCompletedWelcome"
    static let tutorialOfferDismissedKey = "sanne.tutorialOfferDismissed"

    static var hasCompletedWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static var hasDismissedTutorialOffer: Bool {
        get { UserDefaults.standard.bool(forKey: tutorialOfferDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tutorialOfferDismissedKey) }
    }

    static func shouldShowOnboarding(hasCompletedWelcome: Bool) -> Bool {
        !hasCompletedWelcome
    }

    static func shouldOfferTutorial(
        hasCompletedWelcome: Bool,
        tutorialCompleted: Bool,
        offerDismissed: Bool
    ) -> Bool {
        hasCompletedWelcome && !tutorialCompleted && !offerDismissed
    }

    static var shouldOfferTutorial: Bool {
        shouldOfferTutorial(
            hasCompletedWelcome: hasCompletedWelcome,
            tutorialCompleted: TutorialPrefs.completed,
            offerDismissed: hasDismissedTutorialOffer
        )
    }

    /// Existing installs have a config file but no welcome key. Treat welcome as already
    /// done so an upgrade is not a surprise first-run.
    static func adoptExistingInstall(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: completedKey) == nil {
            defaults.set(true, forKey: completedKey)
        }
    }

    /// Fresh config (no file on disk). Write `false` so a later load can tell this apart
    /// from an upgrade that never had the key.
    static func markFreshInstall(defaults: UserDefaults = .standard) {
        if defaults.object(forKey: completedKey) == nil {
            defaults.set(false, forKey: completedKey)
        }
    }

    static func completeWelcome() {
        hasCompletedWelcome = true
    }

    static func dismissTutorialOffer() {
        hasDismissedTutorialOffer = true
    }
}
