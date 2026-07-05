import Foundation

enum DiagnosticsLogger {
    private static let lock = NSLock()

    static func log(_ message: String) {
        guard let outputURL else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }

        if !FileManager.default.fileExists(atPath: outputURL.path) {
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: outputURL) else { return }
        defer {
            try? handle.close()
        }

        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {}
    }

    private static var outputURL: URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = documentsURL.appendingPathComponent("KineticVelocity", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("diagnostics.log")
    }
}
