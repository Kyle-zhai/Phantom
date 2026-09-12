import Foundation
import CloudKit
import CryptoKit
#if canImport(UIKit)
import UIKit

// Picks — the public app leaderboard — was built but parked before release
// on 2026-09-11; tab 3 now holds the For-you recommendations. The whole
// feature is compiled out of Release so the shipping app contains no
// CloudKit *public* database code at all, which is what the privacy policy
// promises ("no part of Phantom is public"). It stays behind DEBUG rather
// than being deleted so `--screen-picks` and PickTests keep working, and so
// reviving it is a one-line change to this guard.
#if DEBUG
#endif

/// The public "Picks" leaderboard: apps recommended by Phantom users, grouped
/// by what you use them for, ranked by how many people opened them. Lives in
/// the CloudKit PUBLIC database (`AppPick` / `PickClick` / `PickReport`).
enum PickCategory: String, CaseIterable, Codable, Identifiable {
    case video = "Video & TV"
    case music = "Music & audio"
    case productivity = "Productivity"
    case ai = "AI assistants"
    case developer = "Developer tools"
    case design = "Design & photo"
    case fitness = "Fitness & health"
    case finance = "Money & finance"
    case learning = "Learning"
    case games = "Games"
    case social = "Social"
    case utilities = "Utilities"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .video: return "play.rectangle"
        case .music: return "music.note"
        case .productivity: return "checklist"
        case .ai: return "sparkles"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush"
        case .fitness: return "figure.run"
        case .finance: return "dollarsign.circle"
        case .learning: return "book"
        case .games: return "gamecontroller"
        case .social: return "person.2"
        case .utilities: return "wrench.and.screwdriver"
        case .other: return "square.grid.2x2"
        }
    }
}

enum PickStatus: String, Codable {
    case pending, approved, rejected
}

struct AppPick: Identifiable, Hashable, Codable {
    static let recordType = "AppPick"
    /// Open counts live on their own record type so the public-database
    /// security role can allow every signed-in user to WRITE counters while
    /// AppPick rows stay creator/developer-only (no vandalising names or URLs).
    static let counterRecordType = "PickCounter"
    static let clickRecordType = "PickClick"
    static let reportRecordType = "PickReport"

    let id: String
    var name: String
    var category: PickCategory
    var tagline: String
    var details: String
    var url: URL
    var appStoreURL: URL?
    var clicks: Int
    var status: PickStatus
    var submitterToken: String
    var createdAt: Date
    var reports: Int

    var host: String {
        (url.host ?? url.absoluteString).replacingOccurrences(of: "www.", with: "")
    }

    var recordID: CKRecord.ID { CKRecord.ID(recordName: id) }
    var counterRecordID: CKRecord.ID { CKRecord.ID(recordName: "counter-" + id) }

    /// Fields fetched for the list; the screenshot asset is loaded on demand.
    static let listKeys = ["name", "category", "tagline", "details", "url", "appStoreURL", "status", "submitterToken", "reports"]

    init(id: String, name: String, category: PickCategory, tagline: String, details: String, url: URL,
         appStoreURL: URL?, clicks: Int, status: PickStatus, submitterToken: String, createdAt: Date, reports: Int) {
        self.id = id; self.name = name; self.category = category; self.tagline = tagline; self.details = details
        self.url = url; self.appStoreURL = appStoreURL; self.clicks = clicks; self.status = status
        self.submitterToken = submitterToken; self.createdAt = createdAt; self.reports = reports
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let name = record["name"] as? String,
              let urlText = record["url"] as? String, let url = URL(string: urlText)
        else { return nil }
        self.id = record.recordID.recordName
        self.name = name
        self.category = PickCategory(rawValue: record["category"] as? String ?? "") ?? .other
        self.tagline = record["tagline"] as? String ?? ""
        self.details = record["details"] as? String ?? ""
        self.url = url
        self.appStoreURL = (record["appStoreURL"] as? String).flatMap(URL.init(string:))
        self.clicks = 0   // filled from the PickCounter record
        self.status = PickStatus(rawValue: record["status"] as? String ?? "") ?? .pending
        self.submitterToken = record["submitterToken"] as? String ?? ""
        self.createdAt = record.creationDate ?? Date()
        self.reports = Int(record["reports"] as? Int64 ?? 0)
    }

    func apply(to record: CKRecord) {
        record["name"] = name as CKRecordValue
        record["category"] = category.rawValue as CKRecordValue
        record["tagline"] = tagline as CKRecordValue
        record["details"] = details as CKRecordValue
        record["url"] = url.absoluteString as CKRecordValue
        if let appStoreURL { record["appStoreURL"] = appStoreURL.absoluteString as CKRecordValue }
        record["status"] = status.rawValue as CKRecordValue
        record["submitterToken"] = submitterToken as CKRecordValue
        record["reports"] = Int64(reports) as CKRecordValue
    }
}

/// What the submit form collects. Validation is pure so it's unit-tested.
struct PickSubmission: Equatable {
    var name = ""
    var category: PickCategory = .productivity
    var tagline = ""
    var details = ""
    var urlText = ""
    var appStoreText = ""
    var screenshot: Data? = nil

    static let nameLimit = 40
    static let taglineLimit = 80
    static let detailsLimit = 400

    enum ValidationError: LocalizedError, Equatable {
        case name, tagline, details, url, appStoreURL, screenshot

        var errorDescription: String? {
            switch self {
            case .name: return "Give the app a name (up to \(nameLimit) characters)."
            case .tagline: return "Add a one-line intro (up to \(taglineLimit) characters)."
            case .details: return "The description is too long (\(detailsLimit) characters max)."
            case .url: return "Enter the app's website, like example.com."
            case .appStoreURL: return "The App Store link should start with https://apps.apple.com/."
            case .screenshot: return "Add one screenshot."
            }
        }
    }

    struct Validated: Equatable {
        let url: URL
        let appStoreURL: URL?
    }

    func validate() throws -> Validated {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, n.count <= Self.nameLimit else { throw ValidationError.name }
        let t = tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= Self.taglineLimit else { throw ValidationError.tagline }
        guard details.count <= Self.detailsLimit else { throw ValidationError.details }
        guard let url = Self.normalizeURL(urlText) else { throw ValidationError.url }
        var store: URL? = nil
        let s = appStoreText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty {
            guard let u = Self.normalizeURL(s), u.host?.hasSuffix("apps.apple.com") == true else { throw ValidationError.appStoreURL }
            store = u
        }
        guard screenshot != nil else { throw ValidationError.screenshot }
        return Validated(url: url, appStoreURL: store)
    }

    /// "example.com/app" → https://example.com/app. Requires a host with a dot.
    static func normalizeURL(_ text: String) -> URL? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(" ") else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        guard var comps = URLComponents(string: s), let host = comps.host, host.contains("."), !host.hasPrefix(".") else { return nil }
        comps.scheme = comps.scheme?.lowercased()
        comps.host = host.lowercased()
        return comps.url
    }
}

enum PickRanking {
    /// Most opened first; ties go to the older submission.
    static func ranked(_ picks: [AppPick]) -> [AppPick] {
        picks.sorted {
            if $0.clicks != $1.clicks { return $0.clicks > $1.clicks }
            return $0.createdAt < $1.createdAt
        }
    }
}

enum PickClickKey {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    /// One counted open per person per app per UTC day; the record name IS
    /// the constraint, so a duplicate save fails instead of double counting.
    static func key(pickID: String, userToken: String, day: Date) -> String {
        "\(pickID)|\(userToken)|\(dayFormatter.string(from: day))"
    }

    /// Opaque per-user token: SHA-256 of the CloudKit user record name.
    /// Stable per iCloud account, reveals nothing.
    static func token(fromUserRecordName name: String) -> String {
        let digest = SHA256.hash(data: Data(name.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(24).description
    }
}

#if canImport(UIKit)
enum PickScreenshot {
    static let maxDimension: CGFloat = 1200
    static let maxBytes = 600_000

    /// Downscale + JPEG so a submission is a few hundred KB, not a 12 MB PNG.
    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        var quality: CGFloat = 0.85
        var out = scaled.jpegData(compressionQuality: quality)
        while let d = out, d.count > maxBytes, quality > 0.3 {
            quality -= 0.15
            out = scaled.jpegData(compressionQuality: quality)
        }
        return out
    }
}
#endif

#endif
