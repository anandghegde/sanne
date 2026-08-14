import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppController
    /// Called when the user leaves onboarding. `startTutorial` is true if they chose the tour.
    var onFinished: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 56, height: 56)
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Welcome to Sanne")
                            .font(.title.weight(.semibold))
                        Text("Gestures that feel like they belong on macOS")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SanneFeatureRow(
                        systemImage: "computermouse",
                        title: "Silent taps on Magic Mouse",
                        detail: "Left, right, middle — no physical click required."
                    )
                    SanneFeatureRow(
                        systemImage: "rectangle.split.2x1",
                        title: "Swipe title bars to snap",
                        detail: "Halves, thirds, quarters, maximize, and more."
                    )
                    SanneFeatureRow(
                        systemImage: "slider.horizontal.3",
                        title: "Opinionated defaults",
                        detail: "Works out of the box. Change anything later."
                    )
                }
                .padding(14)
                .background(SanneChrome.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(SanneChrome.subtleBorder, lineWidth: 1)
                )
            }
            .padding(24)

            Divider().opacity(0.5)

            // Permission strip
            VStack(alignment: .leading, spacing: 12) {
                Text("Sanne needs Accessibility to move windows and recognize gestures. Nothing leaves this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    SanneStatusPill(
                        title: app.accessibilityTrusted ? "Accessibility granted" : "Waiting for Accessibility…",
                        kind: app.accessibilityTrusted ? .ok : .warning
                    )
                    Spacer()
                }

                HStack {
                    if !app.accessibilityTrusted {
                        Button("Open System Settings") {
                            Permissions.openAccessibilitySettings()
                            app.requestAccessibility()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Quit") {
                            NSApp.terminate(nil)
                        }
                    } else {
                        Button("Skip") {
                            finishWelcome(startTutorial: false)
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button("Start Tutorial") {
                            finishWelcome(startTutorial: true)
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                    }
                }

                Text("Enable the Sanne binary shown in Privacy → Accessibility:\n\(Permissions.processPath)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
            .padding(24)
        }
        .frame(width: 520, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func finishWelcome(startTutorial: Bool) {
        WelcomePrefs.completeWelcome()
        app.showOnboarding = false
        onFinished(startTutorial)
    }
}
