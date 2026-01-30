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
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.emacsctl.logger", qos: .utility)
    
    private init() {
        // Create log file at ~/.cache/emacsctl.log
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache")
        
        // Ensure .cache directory exists
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        logFileURL = cacheDir.appendingPathComponent("emacsctl.log")
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // Open file handle for appending
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
        
        // Setup date formatter
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    private func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)\n"
        
        queue.async { [weak self] in
            guard let self = self, let data = logMessage.data(using: .utf8) else { return }
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
