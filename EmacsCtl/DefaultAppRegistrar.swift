//
//  DefaultAppRegistrar.swift
//  EmacsCtl
//
//  Registers EmacsCtl as the macOS default-open application for a configurable
//  list of file extensions, by shelling out to `swda` (SwiftDefaultApps).
//

import Foundation
import UniformTypeIdentifiers
import UserNotifications

class DefaultAppRegistrar {

    static let shared = DefaultAppRegistrar()

    private static let candidateBinaries = [
        "/opt/homebrew/bin/swda",
        "/usr/local/bin/swda",
    ]

    private init() {}

    /// Parse a comma-separated list of extensions into a normalized list.
    /// Trims whitespace, drops a leading dot, lowercases, removes empties.
    static func parseExtensions(_ raw: String) -> [String] {
        return raw
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
            .map { $0.lowercased() }
    }

    /// Register EmacsCtl as the default app for each of the given extensions.
    func registerAsDefault(forExtensions exts: [String]) {
        guard !exts.isEmpty else {
            Logger.info("no extensions to register")
            return
        }

        guard let swda = locateSwda() else {
            Logger.warning("swda not found; skipping default-app registration")
            displayNote(
                title: "swda not found",
                body: "Install with: brew install --cask swiftdefaultappsprefpane"
            )
            return
        }

        let bundleId = Bundle.main.bundleIdentifier ?? "com.tctony.EmacsCtl"
        Logger.info("registering as default for: \(exts.joined(separator: ",")) using \(swda)")

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            var failures: [String] = []
            for ext in exts {
                guard let uti = self.utiForExtension(ext) else {
                    Logger.warning("no UTI for .\(ext); skipping")
                    failures.append(ext)
                    continue
                }

                let (code, output) = self.runSync(swda, args: [
                    "setHandler", "--UTI", uti, "--app", bundleId,
                ])
                Logger.info("swda setHandler .\(ext) (\(uti)) -> \(code): \(output)")
                if code != 0 {
                    failures.append(ext)
                }
            }

            DispatchQueue.main.async {
                if failures.isEmpty {
                    self.displayNote(
                        title: "Default app updated",
                        body: "Registered EmacsCtl for: \(exts.joined(separator: ", "))"
                    )
                } else {
                    self.displayNote(
                        title: "Default app partially updated",
                        body: "Failed: \(failures.joined(separator: ", "))"
                    )
                }
            }
        }
    }

    // MARK: -

    private func locateSwda() -> String? {
        let fm = FileManager.default
        return Self.candidateBinaries.first { fm.isExecutableFile(atPath: $0) }
    }

    private func utiForExtension(_ ext: String) -> String? {
        if let type = UTType(filenameExtension: ext) {
            return type.identifier
        }
        return nil
    }

    private func runSync(_ binary: String, args: [String]) -> (Int32, String) {
        let process = Process()
        process.launchPath = binary
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (process.terminationStatus, out)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    private func displayNote(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        displayNotification(content)
    }
}
