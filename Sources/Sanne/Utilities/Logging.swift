import Combine
import Darwin
import Foundation
import os.log

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

    func formatted(using formatter: DateFormatter) -> String {
        let ts = formatter.string(from: date)
        return "\(ts) [\(level.rawValue)] [\(category.rawValue)] \(message)"
    }
}

/// Prints to stdout when attached to a TTY, appends to `~/Library/Logs/Sanne/sanne.log`,
/// and feeds Debug UI at most 10 Hz while a subscriber is visible.
final class LogRing: ObservableObject, @unchecked Sendable {
    static let shared = LogRing()
    static let debugLoggingDefaultsKey = "debugLogging"

    @MainActor @Published private(set) var lines: [LogLine] = []
    @MainActor @Published var logEveryTouchFrame = false {
        didSet { setLogEveryTouchFrame(logEveryTouchFrame) }
    }

    private let lock = NSLock()
    private var nextID: UInt64 = 1
    private var lineBuffer: [LogLine] = []
    private let maxLines = 4000
    private let fileURL: URL
    private let fileQueue = DispatchQueue(label: "app.sanne.log.file")
    private var subscriberCount = 0
    private var debugFlag = false
    private var everyTouchFrame = false
    private var lastTouchFrameLog: TimeInterval = 0
    private var lastPublishedID: UInt64 = 0
    private var publishTimer: DispatchSourceTimer?
    private let writeStdout: Bool
    private let osLoggers: [LogCategory: Logger] = {
        var map: [LogCategory: Logger] = [:]
        for category in [
            LogCategory.app, .touch, .mt, .tap, .click, .key, .gesture, .zone, .window, .config, .ax
        ] {
            map[category] = Logger(subsystem: "app.sanne", category: category.rawValue)
        }
        return map
    }()

    private static let fileTimestampFormatter: DateFormatter = {
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
        writeStdout = isatty(STDOUT_FILENO) != 0
        debugFlag = UserDefaults.standard.bool(forKey: Self.debugLoggingDefaultsKey)
        let header = "--- Sanne session \(ISO8601DateFormatter().string(from: Date())) pid=\(ProcessInfo.processInfo.processIdentifier) ---\n"
        try? header.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    var isDebugEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return debugFlag || subscriberCount > 0
    }

    func setDebugLogging(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.debugLoggingDefaultsKey)
        lock.lock()
        debugFlag = on
        lock.unlock()
    }

    func addSubscriber() {
        lock.lock()
        subscriberCount += 1
        let start = subscriberCount == 1
        lock.unlock()
        if start {
            DispatchQueue.main.async { self.startPublishTimer() }
        }
    }

    func removeSubscriber() {
        lock.lock()
        subscriberCount = max(0, subscriberCount - 1)
        let stop = subscriberCount == 0
        lock.unlock()
        if stop {
            DispatchQueue.main.async { self.stopPublishTimer() }
        }
    }

    private func setLogEveryTouchFrame(_ on: Bool) {
        lock.lock()
        everyTouchFrame = on
        lock.unlock()
    }

    /// Frame logs are off unless Debug Log (or the UserDefaults flag) is on, the toggle is
    /// on, and we have not logged a frame in the last 50 ms (~20 Hz).
    func shouldLogTouchFrame(now: TimeInterval = CFAbsoluteTimeGetCurrent()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard (debugFlag || subscriberCount > 0), everyTouchFrame else { return false }
        if now - lastTouchFrameLog < 0.05 { return false }
        lastTouchFrameLog = now
        return true
    }

    @MainActor
    func clear() {
        lock.lock()
        lineBuffer.removeAll()
        lastPublishedID = 0
        lock.unlock()
        lines = []
        try? "--- cleared \(ISO8601DateFormatter().string(from: Date())) ---\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func append(level: LogLevel, category: LogCategory, _ message: String) {
        if level < .info, !isDebugEnabled { return }

        lock.lock()
        let id = nextID
        nextID += 1
        let line = LogLine(id: id, date: Date(), level: level, category: category, message: message)
        lineBuffer.append(line)
        if lineBuffer.count > maxLines {
            lineBuffer.removeFirst(lineBuffer.count - maxLines)
        }
        lock.unlock()

        PerfCounters.incLogAppends()

        let echoTTY = writeStdout
        fileQueue.async { [fileURL] in
            let text = line.formatted(using: Self.fileTimestampFormatter)
            if echoTTY {
                fputs(text + "\n", Darwin.stdout)
            }
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

        if let logger = osLoggers[category] {
            switch level {
            case .trace, .debug: logger.debug("\(message, privacy: .public)")
            case .info: logger.info("\(message, privacy: .public)")
            case .warn: logger.warning("\(message, privacy: .public)")
            case .error: logger.error("\(message, privacy: .public)")
            }
        }
    }

    @MainActor
    private func startPublishTimer() {
        guard publishTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.1)
        timer.setEventHandler { [weak self] in
            self?.publishIfNeeded()
        }
        timer.resume()
        publishTimer = timer
        publishIfNeeded()
    }

    @MainActor
    private func stopPublishTimer() {
        publishTimer?.cancel()
        publishTimer = nil
    }

    @MainActor
    private func publishIfNeeded() {
        lock.lock()
        let lastID = lineBuffer.last?.id ?? 0
        guard lastID != lastPublishedID else {
            lock.unlock()
            return
        }
        lastPublishedID = lastID
        let snapshot = lineBuffer
        lock.unlock()
        lines = snapshot
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
