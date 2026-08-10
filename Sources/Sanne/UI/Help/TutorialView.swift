import SwiftUI

/// Short guided walkthrough (≤90s). Listens for live gesture signals; Skip / Done always available.
struct TutorialView: View {
    var onOpenCheatSheet: () -> Void = {}
    var onFinished: () -> Void = {}

    @State private var stepIndex = 0
    @State private var stepCompleted = false
    @State private var statusLine = ""

    private var steps: [Step] {
        [
            Step(
                id: "welcome",
                title: "You’re almost set",
                body: "Sanne lives in the menu bar. This quick tour covers the two moments that matter most — then a few extras.",
                systemImage: "hand.draw",
                signal: nil,
                hint: nil
            ),
            Step(
                id: "mm-tap",
                title: "Silent click (Magic Mouse)",
                body: "If you have a Magic Mouse, lightly tap the left side of the surface — no physical click needed.\n\nNo Magic Mouse? Skip this step.",
                systemImage: "computermouse",
                signal: .magicMouseClick,
                hint: "Waiting for a left tap…"
            ),
            Step(
                id: "titlebar",
                title: "Snap a window",
                body: "1. Open any window (Finder is fine)\n2. Put the pointer on the title bar\n3. Two-finger swipe right on the trackpad\n\nThe window should snap to the right half. Swipe the same way again to restore.",
                systemImage: "rectangle.split.2x1",
                signal: .titlebarSnap,
                hint: "Waiting for a titlebar snap…"
            ),
            Step(
                id: "middle",
                title: "Middle-click (optional)",
                body: "On the trackpad, three-finger tap in free space → middle-click (handy for browser tabs).\n\nOn Magic Mouse: two- or three-finger touch also middle-clicks.",
                systemImage: "hand.tap",
                signal: .trackpadMiddleClick,
                hint: "Waiting for middle-click… (or Skip)"
            ),
            Step(
                id: "more",
                title: "Keyboard & more",
                body: "• ⌃⌥ + arrows — snap / cycle thirds\n• ⌃⌥⌘ + ←/→ — move to another display\n• ⌥⌘ + drag — move window from anywhere\n• ⌃⌘ + drag — resize from nearest edge\n• Trackpad: 3-finger drag — select text / drag items\n• Magic Mouse: 2 fingers on top edge + move → drag window\n\nDock icons and the menu bar also accept two-finger swipes. Remap any gesture in Settings → Gestures (including common keystrokes).",
                systemImage: "keyboard",
                signal: nil,
                hint: nil
            ),
            Step(
                id: "done",
                title: "You’re ready",
                body: "Open Settings anytime from the menu bar to tweak or turn off individual gestures. Reset to Sanne Standard if you want the defaults back.",
                systemImage: "checkmark.circle",
                signal: nil,
                hint: nil
            ),
        ]
    }

    private var step: Step { steps[stepIndex] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }
    private var isFirst: Bool { stepIndex == 0 }
    private var progress: Double { Double(stepIndex + 1) / Double(steps.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress header
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Tutorial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(stepIndex + 1) / \(steps.count)")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(8, geo.size.width * progress))
                            .animation(.easeInOut(duration: 0.25), value: stepIndex)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 56, height: 56)
                        Image(systemName: step.systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(step.title)
                            .font(.title2.weight(.semibold))
                        Text(step.body)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if step.signal != nil {
                    HStack(spacing: 10) {
                        if stepCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                            Text("Got it!")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                            Text(statusLine.isEmpty ? (step.hint ?? "Waiting…") : statusLine)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        (stepCompleted ? Color.green : Color.accentColor).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }

                Spacer(minLength: 0)

                HStack {
                    Button("Skip tutorial") {
                        finish(openCheatSheet: false)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if !isFirst {
                        Button("Back") {
                            goBack()
                        }
                    }

                    if step.signal != nil, !stepCompleted {
                        Button("Skip step") {
                            advance()
                        }
                    }

                    if isLast {
                        Button("Open Cheat Sheet") {
                            finish(openCheatSheet: true)
                        }
                        Button("Finish") {
                            finish(openCheatSheet: false)
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(stepCompleted || step.signal == nil ? "Continue" : "Continue anyway") {
                            advance()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 540, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            stepCompleted = step.signal == nil
            statusLine = step.hint ?? ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .sanneTutorialSignal)) { note in
            guard let raw = note.userInfo?["signal"] as? String,
                  let signal = TutorialSignal(rawValue: raw),
                  let needed = step.signal,
                  signal == needed,
                  !stepCompleted
            else { return }
            stepCompleted = true
            statusLine = "Got it!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                if stepCompleted { advance() }
            }
        }
    }

    private func advance() {
        guard stepIndex < steps.count - 1 else { return }
        stepIndex += 1
        stepCompleted = steps[stepIndex].signal == nil
        statusLine = steps[stepIndex].hint ?? ""
    }

    private func goBack() {
        guard stepIndex > 0 else { return }
        stepIndex -= 1
        stepCompleted = steps[stepIndex].signal == nil
        statusLine = steps[stepIndex].hint ?? ""
    }

    private func finish(openCheatSheet: Bool) {
        TutorialPrefs.completed = true
        if openCheatSheet {
            onOpenCheatSheet()
        }
        onFinished()
    }

    private struct Step: Identifiable {
        let id: String
        let title: String
        let body: String
        let systemImage: String
        let signal: TutorialSignal?
        let hint: String?
    }
}
