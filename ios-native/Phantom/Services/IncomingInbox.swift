import Foundation

/// App Group drop-box for files the share extension (or "Open in Phantom")
/// writes so the main app can ingest them on next activation. Images and CSVs
/// only — never credentials.
enum IncomingInbox {
    static let appGroup = "group.com.yinanzhai.phantom"
    private static let folderName = "Incoming"

    private static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    struct Payload {
        var images: [Data]
        var csvs: [Data]
        var isEmpty: Bool { images.isEmpty && csvs.isEmpty }
    }

    static var hasItems: Bool {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
              )
        else { return false }
        return files.contains { !$0.lastPathComponent.hasPrefix(".") }
    }

    /// Called from the share extension / open-in handler. Returns false if the
    /// App Group container isn't available (unsigned simulator is fine; a
    /// missing group capability on device is not).
    @discardableResult
    static func write(data: Data, suggestedName: String, isCSV: Bool) -> Bool {
        guard let dir = directory else { return false }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = isCSV ? "csv" : "bin"
        let safe = suggestedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(safe).\(ext)"
        let url = dir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Drain the inbox. The main app owns deletion so a failed parse can retry
    /// on the next launch if we *don't* call this — we always consume, because
    /// leaving stale screenshots in the group is worse than a one-time miss.
    static func consume() -> Payload {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              )
        else { return Payload(images: [], csvs: []) }

        var images: [Data] = []
        var csvs: [Data] = []
        for url in files {
            defer { try? FileManager.default.removeItem(at: url) }
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            if url.pathExtension.lowercased() == "csv" {
                csvs.append(data)
            } else {
                images.append(data)
            }
        }
        return Payload(images: images, csvs: csvs)
    }
}
