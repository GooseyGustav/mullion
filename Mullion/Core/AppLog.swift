import Foundation

/// Minimal file logger. A TCC problem is invisible from the outside — the app has to
/// say what it thinks its permissions are, or the only signal is "nothing happened".
///
/// Writes to ~/Library/Logs/Mullion.log. Read it with:
///     tail -f ~/Library/Logs/Mullion.log
enum AppLog {
    private static let url = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Mullion.log")

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func write(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    static func permissionSnapshot(_ context: String) -> String {
        "\(context) accessibility=\(Permissions.hasAccessibility) "
            + "screenRecording=\(Permissions.hasScreenRecording) pid=\(ProcessInfo.processInfo.processIdentifier)"
    }
}
