import Foundation
import os.log
import Combine

enum LogLevel: String, Comparable {
    case trace = "TRACE"
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"

    private var rank: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warn: return 3
        case .error: return 4
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum LogCategory: String {
    case app, touch, mt, tap, click, key, gesture, zone, window, config, ax
}

struct LogLine: Identifiable, Equatable {
    let id: UInt64
    let date: Date
    let level: LogLevel
    let category: LogCategory
    let message: String

    var formatted: String {
        let ts = LogRing.timestampFormatter.string(from: date)
        return "\(ts) [\(level.rawValue)] [\(category.rawValue)] \(message)"
    }
}

/// Prints to stdout (`swift run`), appends to `~/Library/Logs/Sanne/sanne.log`, feeds Debug UI.
final class LogRing: ObservableObject, @unchecked Sendable {
    static let shared = LogRing()

    @MainActor @Published private(set) var lines: [LogLine] = []
    @MainActor @Published var logEveryTouchFrame = true

    private let lock = NSLock()
    private var nextID: UInt64 = 1
    private var lineBuffer: [LogLine] = []
    private let maxLines = 4000
    private let fileURL: URL
    private let fileQueue = DispatchQueue(label: "app.sanne.log.file")

    static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var logFilePath: String { fileURL.path }

    private init() {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/Sanne", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        fileURL = logs.appendingPathComponent("sanne.log")
        let header = "--- Sanne session \(ISO8601DateFormatter().string(from: Date())) pid=\(ProcessInfo.processInfo.processIdentifier) ---\n"
        try? header.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    @MainActor
    func clear() {
        lock.lock()
        lineBuffer.removeAll()
        lock.unlock()
        lines = []
        try? "--- cleared \(ISO8601DateFormatter().string(from: Date())) ---\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func append(level: LogLevel, category: LogCategory, _ message: String) {
        lock.lock()
        let id = nextID
        nextID += 1
        let line = LogLine(id: id, date: Date(), level: level, category: category, message: message)
        lineBuffer.append(line)
        if lineBuffer.count > maxLines {
            lineBuffer.removeFirst(lineBuffer.count - maxLines)
        }
        let snapshot = lineBuffer
        let text = line.formatted
        lock.unlock()

        fputs(text + "\n", stdout)
        fflush(stdout)

        fileQueue.async { [fileURL] in
            guard let data = (text + "\n").data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL)
            {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }

        DispatchQueue.main.async {
            self.lines = snapshot
        }

        let logger = Logger(subsystem: "app.sanne", category: category.rawValue)
        switch level {
        case .trace, .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warn: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }
}

enum Log {
    static func trace(_ category: LogCategory, _ message: String) {
        LogRing.shared.append(level: .trace, category: category, message)
    }

    static func debug(_ category: LogCategory, _ message: String) {
        LogRing.shared.append(level: .debug, category: category, message)
    }

    static func info(_ category: LogCategory, _ message: String) {
        LogRing.shared.append(level: .info, category: category, message)
    }

    static func warn(_ category: LogCategory, _ message: String) {
        LogRing.shared.append(level: .warn, category: category, message)
    }

    static func error(_ category: LogCategory, _ message: String) {
        LogRing.shared.append(level: .error, category: category, message)
    }
}
