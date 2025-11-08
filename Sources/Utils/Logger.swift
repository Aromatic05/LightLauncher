import Foundation
import os

/// 全局 Logger
/// 默认行为：
/// - 使用 os.Logger 输出到系统统一日志（如果可用）
/// - 同时输出到终端（print），以便在本地运行时即时查看
/// - 文件记录默认关闭；如果启用，会在 `~/.cache/LightLauncher/<YYYY-MM-DD>/` 下为每次启动创建单独日志文件
final class Logger: @unchecked Sendable {
    static let shared = Logger()

    enum Level: Int, Comparable, CustomStringConvertible {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        var description: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            }
        }

        static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    private var osLogger: os.Logger?
    private let fileQueue = DispatchQueue(label: "com.lightlauncher.logger.file", qos: .utility)

    // 输出控制
    private(set) var consoleLevel: Level = .info  // 控制 osLogger / terminal 的最小输出等级
    private(set) var fileLevel: Level = .debug  // 控制文件写入的最小输出等级

    private(set) var logToOSLog: Bool = true
    private(set) var printToTerminal: Bool = true
    private(set) var logToFile: Bool = false

    private var fileURL: URL? = nil

    private init() {
        if #available(macOS 11.0, *) {
            osLogger = os.Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "com.lightlauncher",
                category: "LightLauncher")
        } else {
            osLogger = nil
        }
    }

    /// 配置 Logger
    /// - Parameters:
    ///   - logToOSLog: 是否将日志发送到系统统一日志
    ///   - printToTerminal: 是否在终端用 print 输出（方便本地开发）
    ///   - logToFile: 是否启用文件写入
    ///   - consoleLevel: 控制台/终端最小日志等级
    ///   - fileLevel: 文件写入最小等级
    ///   - customFileURL: 自定义日志文件（如果为 nil 且启用文件写入，将使用 per-session 文件放在 ~/.cache/LightLauncher/<date>/ ）
    func configure(
        logToOSLog: Bool = true,
        printToTerminal: Bool = true,
        logToFile: Bool = false,
        consoleLevel: Level = .info,
        fileLevel: Level = .debug,
        customFileURL: URL? = nil
    ) {
        self.logToOSLog = logToOSLog
        self.printToTerminal = printToTerminal
        self.consoleLevel = consoleLevel
        self.fileLevel = fileLevel

        if logToFile {
            // enable file logging: set up file URL
            self.logToFile = true
            if let custom = customFileURL {
                self.fileURL = custom
                try? FileManager.default.createDirectory(
                    at: custom.deletingLastPathComponent(), withIntermediateDirectories: true)
            } else {
                startNewSessionLogFile()
            }
        } else {
            self.logToFile = false
            self.fileURL = nil
        }
    }

    /// 每次启动调用，建立新的 session 文件（如果文件记录被启用或将要启用）
    func startNewSessionLogFile() {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/LightLauncher", isDirectory: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let day = dateFormatter.string(from: Date())

        let sessionDir = cacheDir.appendingPathComponent(day, isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmmss"
        let t = timeFormatter.string(from: Date())

        let filename = "lightlauncher-\(t).log"
        let url = sessionDir.appendingPathComponent(filename)
        self.fileURL = url
    }

    // MARK: - Logging

    private func shouldLogToConsole(level: Level) -> Bool {
        return level >= consoleLevel && (logToOSLog || printToTerminal)
    }

    private func shouldLogToFile(level: Level) -> Bool {
        return logToFile && level >= fileLevel && fileURL != nil
    }

    private func composeMessage(
        level: Level, owner: Any?, file: String, function: String, line: Int, message: String
    ) -> String {
        let ts = ISO8601DateFormatter().string(from: Date())
        var prefix = "[\(ts)] [\(level.description)]"
        if let owner = owner {
            prefix += " [\(String(describing: type(of: owner)))]"
        }
        let filename = (file as NSString).lastPathComponent
        prefix += " [\(filename):\(line) \(function)]"
        return "\(prefix) \(message)"
    }

    private func writeToOSLog(_ text: String, level: Level) {
        if #available(macOS 11.0, *), let o = osLogger {
            switch level {
            case .debug:
                o.debug("\(text, privacy: .public)")
            case .info:
                o.info("\(text, privacy: .public)")
            case .warning:
                o.warning("\(text, privacy: .public)")
            case .error:
                o.error("\(text, privacy: .public)")
            }
        } else {
            // fallback
            print(text)
        }
    }

    private func appendToFile(_ text: String) {
        guard let url = fileURL else { return }
        let data = (text + "\n").data(using: .utf8) ?? Data()
        fileQueue.async { [weak self] in
            guard self != nil else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    do {
                        try handle.seekToEnd()
                    } catch {
                        // ignore seek error
                    }
                    handle.write(data)
                } else {
                    try? data.write(to: url, options: .atomic)
                }
            } else {
                try? data.write(to: url)
            }
        }
    }

    // Public API: 支持延迟构造 message
    func log(
        _ level: Level,
        _ message: @autoclosure () -> String,
        owner: Any? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let shouldConsole = shouldLogToConsole(level: level)
        let shouldFile = shouldLogToFile(level: level)

        if !shouldConsole && !shouldFile { return }

        let msg = message()
        let composed = composeMessage(
            level: level, owner: owner, file: file, function: function, line: line, message: msg)

        if shouldConsole {
            if logToOSLog {
                writeToOSLog(composed, level: level)
            }
            if printToTerminal {
                print(composed)
            }
        }

        if shouldFile {
            appendToFile(composed)
        }
    }

    // 便捷方法
    func debug(
        _ message: @autoclosure () -> String, owner: Any? = nil, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        log(.debug, message(), owner: owner, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String, owner: Any? = nil, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        log(.info, message(), owner: owner, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String, owner: Any? = nil, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        log(.warning, message(), owner: owner, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String, owner: Any? = nil, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        log(.error, message(), owner: owner, file: file, function: function, line: line)
    }

    /// 根据 `AppConfig.LoggingConfig` 应用配置（便于在 App 启动时从配置中心统一设置）
    func apply(config: AppConfig.LoggingConfig) {
        func mapLevel(_ l: AppConfig.LoggingConfig.LogLevel) -> Logger.Level {
            switch l {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .warning
            case .error: return .error
            }
        }

        let customURL: URL? = config.customFilePath.flatMap { path in
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }

        configure(
            logToOSLog: true,
            printToTerminal: config.printToTerminal,
            logToFile: config.logToFile,
            consoleLevel: mapLevel(config.consoleLevel),
            fileLevel: mapLevel(config.fileLevel),
            customFileURL: customURL
        )

        if config.logToFile && customURL == nil {
            startNewSessionLogFile()
        }
    }
}
