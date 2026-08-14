import SwiftUI

/// Short guided walkthrough (≤90s). Listens for live gesture signals; Skip / Done always available.
struct TutorialView: View {
    var onOpenCheatSheet: () -> Void = {}
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stepIndex = 0
    @State private var stepCompleted = false
    @State private var statusLine = ""
    @State private var hasMagicMouse = IOKitHints.applePointers().contains(where: \.isMouse)

    private var steps: [Step] {
        var list: [Step] = [
            Step(
                id: "welcome",
                title: "You’re almost set",
                body: hasMagicMouse
                    ? "Sanne lives in the menu bar. This tour covers silent taps and titlebar snap."
                    : "Sanne lives in the menu bar. This tour covers titlebar snap and a middle-click.\n\nConnect a Magic Mouse for silent taps.",
                systemImage: "hand.draw",
                diagram: nil,
                signal: nil,
                hint: nil
            )
        ]
        if hasMagicMouse {
            list.append(
                Step(
                    id: "mm-tap",
                    title: "Silent click",
                    body: "Lightly tap the left side of the Magic Mouse surface — no physical click needed.",
                    systemImage: "computermouse",
                    diagram: .mouse(1, .tap, side: .left),
                    signal: .magicMouseClick,
                    hint: "Waiting for a left tap…"
                )
            )
        }
        list.append(
            Step(
                id: "titlebar",
                title: "Snap a window",
                body: "1. Open any window (Finder is fine)\n2. Put the pointer on the title bar\n3. Two-finger swipe right",
                systemImage: "rectangle.split.2x1",
                diagram: .trackpad(2, .swipe(.right), zone: .topEdge),
                signal: .titlebarSnap,
                hint: "Waiting for a titlebar snap…"
            )
        )
        if hasMagicMouse {
            list.append(
                Step(
                    id: "middle",
                    title: "Middle-click",
                    body: "Two- or three-finger touch on the Magic Mouse — handy for browser tabs.",
                    systemImage: "hand.tap",
                    diagram: .mouse(2, .touch),
                    signal: .trackpadMiddleClick,
                    hint: "Waiting for a middle-click…"
                )
            )
        } else {
            list.append(
                Step(
                    id: "middle",
                    title: "Middle-click",
                    body: "Three-finger tap in free space on the trackpad — handy for browser tabs.",
                    systemImage: "hand.tap",
                    diagram: .trackpad(3, .tap),
                    signal: .trackpadMiddleClick,
                    hint: "Waiting for a three-finger tap…"
                )
            )
            list.append(
                Step(
                    id: "dock",
                    title: "Dock swipe (optional)",
                    body: "Two-finger swipe up on a Dock icon to activate that app.",
                    systemImage: "dock.rectangle",
                    diagram: .trackpad(2, .swipe(.up), zone: .bottomEdge),
                    signal: .dockActivate,
                    hint: "Waiting for a Dock swipe up…"
                )
            )
        }
        list.append(
            Step(
                id: "done",
                title: "You’re ready",
                body: "⌃⌥ arrows snap. Remap anything in Settings.",
                systemImage: "checkmark.circle",
                diagram: nil,
                signal: nil,
                hint: nil
            )
        )
        return list
    }

    private var step: Step { steps[min(stepIndex, steps.count - 1)] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }
    private var isFirst: Bool { stepIndex == 0 }
    private var progress: Double { Double(stepIndex + 1) / Double(max(steps.count, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: stepIndex)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    if let diagram = step.diagram {
                        GestureDiagramView(diagram: diagram, size: 80)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 56, height: 56)
                            Image(systemName: step.systemImage)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
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
        .frame(width: 540, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            hasMagicMouse = IOKitHints.applePointers().contains(where: \.isMouse)
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
        let diagram: GestureDiagram?
        let signal: TutorialSignal?
        let hint: String?
    }
}
