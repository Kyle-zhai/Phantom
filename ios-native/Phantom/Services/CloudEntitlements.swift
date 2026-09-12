import Foundation

/// Whether this binary was signed with the iCloud/CloudKit entitlement.
/// CloudKit aborts the process the moment a `CKContainer` is created without
/// it, and unsigned simulator / CI builds (`CODE_SIGNING_ALLOWED=NO`) have no
/// entitlements at all — so every CloudKit touch checks this first.
///
/// iOS has no public "read my own entitlements" API, so this reads the code
/// signature embedded in the app's own Mach-O (LC_CODE_SIGNATURE → SuperBlob
/// → entitlements plist). Anything unexpected → "no entitlement".
enum CloudEntitlements {
    static let entitlements: [String: Any] = {
        guard let url = Bundle.main.executableURL, let data = try? Data(contentsOf: url) else { return [:] }
        return MachOEntitlements.parse(data) ?? [:]
    }()

    static let hasCloudKit: Bool = {
        guard let services = entitlements["com.apple.developer.icloud-services"] as? [String] else { return false }
        return services.contains("CloudKit") || services.contains("CloudKit-Anonymous")
    }()

    static let hasSignInWithApple: Bool = {
        (entitlements["com.apple.developer.applesignin"] as? [String])?.isEmpty == false
    }()
}

/// Minimal Mach-O reader: enough to pull the entitlements plist out of a
/// thin or fat binary. Device builds carry it in the code signature
/// (LC_CODE_SIGNATURE → SuperBlob); Xcode's simulator builds carry a
/// "simulated" copy in the `__TEXT,__entitlements` section instead. Both are
/// checked. Pure, so it's unit-tested against synthetic images.
enum MachOEntitlements {
    private static let magic64: UInt32 = 0xfeedfacf
    private static let fatMagic: UInt32 = 0xcafebabe
    private static let lcSegment64: UInt32 = 0x19
    private static let lcCodeSignature: UInt32 = 0x1d
    private static let superBlobMagic: UInt32 = 0xfade0cc0
    private static let entitlementsBlobMagic: UInt32 = 0xfade7171
    private static let entitlementsSlot: UInt32 = 5

    static func parse(_ data: Data) -> [String: Any]? {
        guard data.count >= 8 else { return nil }
        let magicBE = readBE(data, 0)
        if magicBE == fatMagic {
            let count = Int(readBE(data, 4))
            for i in 0..<min(count, 16) {
                let base = 8 + i * 20
                guard base + 20 <= data.count else { break }
                let offset = Int(readBE(data, base + 8))
                let size = Int(readBE(data, base + 12))
                guard offset + size <= data.count, size > 0 else { continue }
                if let ents = parseThin(data.subdata(in: offset..<(offset + size))) { return ents }
            }
            return nil
        }
        return parseThin(data)
    }

    private static func parseThin(_ data: Data) -> [String: Any]? {
        guard data.count >= 32, readLE(data, 0) == magic64 else { return nil }
        let ncmds = Int(readLE(data, 16))
        var cursor = 32
        var fromSignature: [String: Any]? = nil
        var fromSection: [String: Any]? = nil
        for _ in 0..<ncmds {
            guard cursor + 8 <= data.count else { break }
            let cmd = readLE(data, cursor)
            let size = Int(readLE(data, cursor + 4))
            guard size >= 8 else { break }
            if cmd == lcCodeSignature, cursor + 16 <= data.count {
                let dataoff = Int(readLE(data, cursor + 8))
                let datasize = Int(readLE(data, cursor + 12))
                if dataoff + datasize <= data.count {
                    fromSignature = parseSuperBlob(data.subdata(in: dataoff..<(dataoff + datasize)))
                }
            } else if cmd == lcSegment64, fromSection == nil {
                fromSection = parseSegmentForEntitlements(data, at: cursor, size: size)
            }
            cursor += size
        }
        // An ad-hoc simulator signature carries an EMPTY entitlements plist
        // while the real ones sit in __TEXT,__entitlements — prefer whichever
        // actually has keys.
        if let sig = fromSignature, !sig.isEmpty { return sig }
        if let sec = fromSection, !sec.isEmpty { return sec }
        return fromSignature ?? fromSection
    }

    /// LC_SEGMENT_64 "__TEXT" → section "__entitlements" (simulator builds).
    private static func parseSegmentForEntitlements(_ data: Data, at cursor: Int, size: Int) -> [String: Any]? {
        guard size >= 72, cursor + size <= data.count else { return nil }
        guard name(data, cursor + 8, 16) == "__TEXT" else { return nil }
        let nsects = Int(readLE(data, cursor + 64))
        var sect = cursor + 72
        for _ in 0..<nsects {
            guard sect + 80 <= cursor + size else { return nil }
            if name(data, sect, 16) == "__entitlements" {
                let sizeLo = Int(readLE(data, sect + 40))
                let offset = Int(readLE(data, sect + 48))
                guard sizeLo > 0, offset + sizeLo <= data.count else { return nil }
                let plist = data.subdata(in: offset..<(offset + sizeLo))
                return (try? PropertyListSerialization.propertyList(from: plist, format: nil)) as? [String: Any]
            }
            sect += 80
        }
        return nil
    }

    private static func name(_ d: Data, _ at: Int, _ len: Int) -> String {
        guard at + len <= d.count else { return "" }
        let bytes = d.subdata(in: at..<(at + len))
        let trimmed = bytes.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self)
    }

    private static func parseSuperBlob(_ blob: Data) -> [String: Any]? {
        guard blob.count >= 12, readBE(blob, 0) == superBlobMagic else { return nil }
        let count = Int(readBE(blob, 8))
        for i in 0..<min(count, 64) {
            let base = 12 + i * 8
            guard base + 8 <= blob.count else { break }
            let type = readBE(blob, base)
            let offset = Int(readBE(blob, base + 4))
            guard type == entitlementsSlot, offset + 8 <= blob.count, readBE(blob, offset) == entitlementsBlobMagic else { continue }
            let length = Int(readBE(blob, offset + 4))
            guard length >= 8, offset + length <= blob.count else { return nil }
            let plist = blob.subdata(in: (offset + 8)..<(offset + length))
            return (try? PropertyListSerialization.propertyList(from: plist, format: nil)) as? [String: Any]
        }
        return nil
    }

    private static func readLE(_ d: Data, _ at: Int) -> UInt32 {
        guard at + 4 <= d.count else { return 0 }
        return UInt32(d[d.startIndex + at]) | UInt32(d[d.startIndex + at + 1]) << 8
            | UInt32(d[d.startIndex + at + 2]) << 16 | UInt32(d[d.startIndex + at + 3]) << 24
    }

    private static func readBE(_ d: Data, _ at: Int) -> UInt32 {
        guard at + 4 <= d.count else { return 0 }
        return UInt32(d[d.startIndex + at]) << 24 | UInt32(d[d.startIndex + at + 1]) << 16
            | UInt32(d[d.startIndex + at + 2]) << 8 | UInt32(d[d.startIndex + at + 3])
    }
}
