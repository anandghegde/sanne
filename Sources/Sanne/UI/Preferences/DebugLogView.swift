import SwiftUI
import AppKit

struct DebugLogView: View {
    @ObservedObject private var ring = LogRing.shared
    @State private var counters = PerfCounters.snapshotLine()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SannePageHeader(
                title: "Debug Log",
                subtitle: "Tap the Magic Mouse and watch for: mt frames → tap decision → click posted."
            )

            HStack(spacing: 10) {
                Toggle("Every touch frame", isOn: $ring.logEveryTouchFrame)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Clear") { ring.clear() }
                Button("Copy all") { copyAll() }
                Button("Reveal in Finder") { reveal() }
            }

            HStack(spacing: 10) {
                Text(counters)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
                Button("Reset") {
                    PerfCounters.reset()
                    counters = PerfCounters.snapshotLine()
                }
            }

            Text(ring.logFilePath)
                .font(.caption2)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(ring.lines) { line in
                            Text(line.formatted(using: Self.uiFormatter))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(color(for: line.level))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(SanneChrome.subtleBorder, lineWidth: 1)
                )
                .onChange(of: ring.lines.count) { _ in
                    if let last = ring.lines.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(20)
        .onAppear {
            ring.addSubscriber()
            counters = PerfCounters.snapshotLine()
        }
        .onDisappear {
            ring.removeSubscriber()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            counters = PerfCounters.snapshotLine()
        }
    }

    private static let uiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .trace: return .secondary
        case .debug: return .primary
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }

    private func copyAll() {
        let text = ring.lines.map { $0.formatted(using: Self.uiFormatter) }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: ring.logFilePath)])
    }
}
