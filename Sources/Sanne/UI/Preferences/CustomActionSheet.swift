import AppKit
import SwiftUI

/// Editor for one user-defined script action.
///
/// Deliberately a pure input form: it never touches `ConfigStore`, so the presenting view owns
/// persistence and can decide whether a freshly created script should also be bound to the gesture
/// that opened it. That keeps a single writer and makes the sheet reusable from anywhere.
struct CustomActionSheet: View {
    let initial: CustomActionDef
    let onSave: (CustomActionDef) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var kind: CustomActionDef.Kind
    @State private var payload: String
    @State private var shortcutNames: [String] = []
    @State private var loadingShortcuts = false

    init(
        initial: CustomActionDef,
        onSave: @escaping (CustomActionDef) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _kind = State(initialValue: initial.kind)
        _payload = State(initialValue: initial.payload)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameField
                    kindPicker
                    payloadEditor
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 540)
        // Re-runs when the kind changes, so the Shortcuts library is only read once the user
        // actually asks for a shortcut.
        .task(id: kind) {
            await loadShortcutsIfNeeded()
        }
    }

    // MARK: - Sections

    /// Only the always-true framing lives here. How a script runs is per-kind, and the runtime
    /// limits live in the footer, so no single block becomes a wall of text.
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(isNewDef ? "New script action" : "Edit script action")
                .font(.headline)
            hint("Runs in the background when the gesture fires, so a slow script never stalls your input.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var nameField: some View {
        field("Name") {
            TextField("e.g. Toggle Do Not Disturb", text: $name)
                .textFieldStyle(.roundedBorder)
            hint("Shown in the action picker. Gestures reference this script by id, so renaming it keeps every binding intact.")
        }
    }

    private var kindPicker: some View {
        field("Kind") {
            Picker("Kind", selection: $kind) {
                ForEach(CustomActionDef.Kind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var payloadEditor: some View {
        switch kind {
        case .shell:
            scriptField(
                hint: "Run through `/bin/zsh -lc`, so your login `PATH` and profile apply."
            )
        case .appleScript:
            // The user-facing consequence only. Why `osascript` rather than `NSAppleScript` is a
            // detail of the runner, and is documented there.
            scriptField(
                hint: """
                Run through `osascript -e`. The first script that controls another app asks for \
                Automation permission — allow it once and the gesture works from then on.
                """
            )
        case .shortcut:
            shortcutField
        }
    }

    /// Monospaced editor for the two script kinds, with the example shown as a placeholder.
    private func scriptField(hint hintText: LocalizedStringKey) -> some View {
        field(kind.displayName) {
            TextEditor(text: $payload)
                .font(Self.scriptFont)
                // Sized before the placeholder goes on, so `.topLeading` anchors to the box the user
                // actually sees rather than the editor's intrinsic height.
                .frame(minHeight: 190)
                // In front of the editor, not behind it: `TextEditor` draws an opaque background, so
                // a placeholder underneath would be invisible. Same font and insets as the editor's
                // own text, so the example sits exactly where the caret will and nothing shifts the
                // moment typing starts.
                .overlay(alignment: .topLeading) {
                    if payload.isEmpty {
                        Text(verbatim: kind.payloadExample)
                            .font(Self.scriptFont)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, Self.scriptTextInset)
                            .padding(.top, Self.scriptTextTopInset)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: SanneChrome.cornerRadius, style: .continuous)
                        .strokeBorder(SanneChrome.subtleBorder, lineWidth: 1)
                )
            hint(hintText)
        }
    }

    private var shortcutField: some View {
        field("Shortcut") {
            HStack(spacing: 6) {
                TextField(kind.payloadExample, text: $payload)
                    .textFieldStyle(.roundedBorder)
                if loadingShortcuts {
                    ProgressView()
                        .controlSize(.small)
                } else if !shortcutNames.isEmpty {
                    Menu("Choose…") {
                        ForEach(shortcutNames, id: \.self) { name in
                            Button(name) { payload = name }
                        }
                    }
                    .fixedSize()
                }
                // An icon rather than a worded button: this row already carries a field and a menu,
                // and a third labelled control crowds them. Worth keeping even when the menu is
                // populated, since names must match exactly and checking at the source beats guessing.
                Button {
                    ShortcutsIndex.openApp()
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open the Shortcuts app to check a shortcut’s exact name")
            }
            hint(shortcutHint)
        }
    }

    /// The limits note gets its own line above the buttons rather than sharing the row: it is a full
    /// sentence, and the not-runnable warning already needs that horizontal space.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            limitsNote
            HStack(spacing: 10) {
                if !edited.isRunnable {
                    Label("Add something to run first.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(isNewDef ? "Create" : "Save") { onSave(edited) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!edited.isRunnable)
            }
        }
        .padding(16)
    }

    /// Outside the scroll area on purpose: "skipped rather than queued" is the only explanation a
    /// user gets when a gesture appears to do nothing, so it must not be something you scroll to find.
    private var limitsNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            // `verbatim` because this interpolates numbers: as a `LocalizedStringKey` the values
            // would become `%lld` placeholders in the lookup key. It carries no Markdown, so there
            // is nothing to lose.
            Text(verbatim: """
            Scripts are stopped after \(CustomActionLimits.timeoutSeconds) seconds, and at most \
            \(CustomActionLimits.concurrentScripts) run at once — trigger the gesture while that \
            many are still running and the extra run is skipped rather than queued. Errors and \
            skips are recorded in Debug Log.
            """)
            .hintStyle()
        }
    }

    // MARK: - Layout helpers

    private static let scriptFont = Font.system(.body, design: .monospaced)

    /// `NSTextView`'s default line-fragment padding, which is what insets `TextEditor`'s text
    /// horizontally.
    private static let scriptTextInset: CGFloat = 5

    /// `NSTextView`'s default `textContainerInset` height, which insets that same text vertically.
    /// Small but not zero, so without it the placeholder sits a point above the caret.
    private static let scriptTextTopInset: CGFloat = 1

    /// One labelled form row, so the name / kind / payload sections stay aligned identically.
    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.callout.weight(.medium))
            content()
        }
    }

    /// Secondary explanatory line.
    ///
    /// Takes `LocalizedStringKey` rather than `String` on purpose: only that overload of `Text`
    /// parses Markdown, so passing a plain `String` would print the `` `backticks` `` in these
    /// strings literally instead of styling the commands they name.
    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text).hintStyle()
    }

    // MARK: - Derived state

    /// The def as currently edited. Trimming both ends is safe for multi-line scripts and stops a
    /// stray newline from being mistaken for content by `isRunnable`.
    private var edited: CustomActionDef {
        CustomActionDef(
            id: initial.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            payload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Only drives button and title wording, so the heuristic is cheap: saving requires a payload,
    /// which means an empty one can only ever be a def the user just started.
    private var isNewDef: Bool {
        initial.payload.isEmpty && initial.name.isEmpty
    }

    private var shortcutHint: LocalizedStringKey {
        if !ShortcutsIndex.isAvailable {
            return "The `shortcuts` command isn’t available on this Mac, so this action can’t run."
        }
        if loadingShortcuts {
            return "Reading your Shortcuts library…"
        }
        if shortcutNames.isEmpty {
            return "No shortcuts found — type the name exactly as it appears in the Shortcuts app."
        }
        return "Runs `shortcuts run` with this name."
    }

    /// Loads the library once, off-main: `shortcuts list` shells out and can take a moment on a
    /// large library, and this sheet is presented on top of an already-modal picker.
    private func loadShortcutsIfNeeded() async {
        guard kind == .shortcut, shortcutNames.isEmpty, !loadingShortcuts else { return }
        loadingShortcuts = true
        shortcutNames = await Task.detached(priority: .userInitiated) { ShortcutsIndex.names() }.value
        loadingShortcuts = false
    }
}

// MARK: - Shortcuts library

/// Reads the user's Shortcuts library so the sheet can offer a real picker instead of asking the
/// user to retype a name exactly — a typo here fails silently at gesture time.
///
/// A free function on a file-private type rather than a view member, so it is unambiguously safe to
/// call from the detached task that runs it.
private enum ShortcutsIndex {
    static let binaryPath = "/usr/bin/shortcuts"

    /// Older macOS has no `shortcuts` binary at all.
    static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath)
    }

    static func names() -> [String] {
        // Checking first keeps a predictable absence off the log.
        guard isAvailable else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["list"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            Log.warn(.config, "shortcuts list failed to launch: \(error.localizedDescription)")
            return []
        }

        // Drain before waiting: the output is small, but reading first is what keeps the pipe from
        // filling and deadlocking the wait.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Opens the Shortcuts app so the user can confirm a shortcut's exact name.
    ///
    /// Mirrors `ActionRunner.launchApplication`: activates the app so it actually comes forward, and
    /// logs a failure rather than dropping it silently.
    static func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            Log.warn(.config, "Shortcuts app not found")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                Log.warn(.config, "Failed to open Shortcuts: \(error.localizedDescription)")
            }
        }
    }

    private static let bundleId = "com.apple.shortcuts"
}

// MARK: - Chrome

private extension View {
    /// Styling shared by every explanatory line in the sheet.
    ///
    /// Separate from the `Text` itself so each call site can choose between the Markdown-parsing
    /// `LocalizedStringKey` initializer and `verbatim`, without the two drifting in appearance.
    func hintStyle() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension CustomActionDef.Kind {
    /// SF Symbol for the kind. Lives in the UI layer so `CustomActionDef` stays free of chrome.
    ///
    /// `scroll` arrived in SF Symbols 3 and `wand.and.stars` in 1, both below this app's deployment
    /// target, so all three render — no need to fall back to blander stand-ins.
    var glyph: String {
        switch self {
        case .shell: return "terminal"
        case .appleScript: return "scroll"
        case .shortcut: return "wand.and.stars"
        }
    }

    /// Shown as placeholder text. A concrete example explains the field faster than prose can, and
    /// each one is deliberately harmless to run as-is.
    var payloadExample: String {
        switch self {
        case .shell: return "open -a \"Visual Studio Code\" ."
        case .appleScript: return "tell application \"Music\" to playpause"
        case .shortcut: return "Start Focus Session"
        }
    }
}
