//
//  Logger.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/12.
//

import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private var fileHandle: FileHandle?
    private var currentWeek: String
    private let queue = DispatchQueue(label: "com.emacsctl.logger", qos: .utility)

    private init() {
        let logDirectoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache")
        let now = Date()

        // Ensure .cache directory exists
        if !FileManager.default.fileExists(atPath: logDirectoryURL.path) {
            try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        }

        logFileURL = logDirectoryURL.appendingPathComponent("emacsctl.log")

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        let logDate = fileSize > 0 ? (attributes?[.modificationDate] as? Date ?? now) : now
        currentWeek = Self.weekIdentifier(for: logDate)
        fileHandle = nil

        // Setup date formatter
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        rotateIfNeeded(at: now)
        openLogFile()
    }

    deinit {
        try? fileHandle?.close()
    }

    private static func weekIdentifier(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", components.yearForWeekOfYear!, components.weekOfYear!)
    }

    private func openLogFile() {
        guard fileHandle == nil else { return }
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
    }

    private func rotateIfNeeded(at date: Date) {
        let newWeek = Self.weekIdentifier(for: date)
        guard newWeek != currentWeek else { return }

        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil

        let fileManager = FileManager.default
        let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        let modificationDate = attributes?[.modificationDate] as? Date

        if fileSize > 0, let modificationDate {
            let logFileWeek = Self.weekIdentifier(for: modificationDate)

            // Debug and release share this file, so only delete it if it still belongs to an older week.
            if logFileWeek != newWeek {
                try? fileManager.removeItem(at: logFileURL)
            }
        }

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }

        currentWeek = newWeek
        openLogFile()
    }

    private func log(_ level: LogLevel,
                     _ message: String,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        let now = Date()
        let timestamp = dateFormatter.string(from: now)
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)\n"

        queue.async { [weak self] in
            guard let self = self, let data = logMessage.data(using: .utf8) else { return }
            self.rotateIfNeeded(at: now)
            self.fileHandle?.write(data)

            // Also print to console in DEBUG builds
            #if DEBUG
            print(logMessage, terminator: "")
            #endif
        }
    }

    // MARK: - Public Methods
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(.debug, message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(.info, message, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(.warning, message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(.error, message, file: file, function: function, line: line)
    }
    
    // MARK: - Utility
    
    static var logFilePath: String {
        return shared.logFileURL.path
    }
    
    /// Flush any pending writes to disk
    static func flush() {
        shared.queue.sync {
            try? shared.fileHandle?.synchronize()
        }
    }
}
