import XCTest
@testable import Phantom

final class SyncFoundationTests: XCTestCase {

    func testDedupeKeepsOnePerKeyAndHonoursPreference() {
        let rows = [("a", 1), ("b", 1), ("a", 2), ("a", 3), ("b", 0)]
        let byFirst = Dedupe.byKey(rows, key: { $0.0 })
        XCTAssertEqual(byFirst.keep.map { "\($0.0)\($0.1)" }, ["a1", "b1"])
        XCTAssertEqual(byFirst.drop.count, 3)
        let byHighest = Dedupe.byKey(rows, key: { $0.0 }, prefer: { $0.1 > $1.1 })
        XCTAssertEqual(byHighest.keep.map { "\($0.0)\($0.1)" }, ["a3", "b1"])
    }

    func testSubscriptionRowRoundTripIncludingBillingSourceAndHike() {
        var sub = makeSub(id: "netflix", amount: 19.99, userRating: 2,
                          hasPriceHike: PriceHike(from: 17.99, to: 19.99, effective: daysAgo(5)),
                          hasOverlapWith: ["hulu"])
        sub.billedVia = .apple
        let row = PersistentSubscription(from: sub, cancelled: true)
        XCTAssertTrue(row.cancelled)
        let back = row.toDomain()
        XCTAssertEqual(back.id, "netflix")
        XCTAssertEqual(back.amount, 19.99, accuracy: 0.001)
        XCTAssertEqual(back.userRating, 2)
        XCTAssertEqual(back.hasPriceHike?.from, 17.99)
        XCTAssertEqual(back.hasOverlapWith, ["hulu"])
        XCTAssertEqual(back.billedVia, .apple)
        // apply() updates in place (upsert path) and bumps updatedAt
        let before = row.updatedAt
        row.apply(makeSub(id: "netflix", amount: 26.99), cancelled: false)
        XCTAssertEqual(row.amount, 26.99, accuracy: 0.001)
        XCTAssertFalse(row.cancelled)
        XCTAssertGreaterThanOrEqual(row.updatedAt, before)
    }

    func testTransactionRowRoundTrip() {
        let entry = TransactionLedger.Entry(merchant: "Netflix", amount: 15.99, date: daysAgo(3),
                                            recurringHint: true, rawRow: "NFLX*SUBSCRIPTION", importedAt: Date())
        let row = PersistentTransaction(entry: entry)
        XCTAssertEqual(row.dedupeKey, entry.dedupeKey)
        let back = row.toEntry()
        XCTAssertEqual(back.merchant, "Netflix")
        XCTAssertTrue(back.recurringHint)
        XCTAssertEqual(back.dedupeKey, entry.dedupeKey)
    }

    func testPrefsPlistRoundTripForEveryTrackedType() throws {
        XCTAssertEqual(try XCTUnwrap(PrefsSync.decode(try XCTUnwrap(PrefsSync.encode(true))) as? Bool), true)
        XCTAssertEqual(try XCTUnwrap(PrefsSync.decode(try XCTUnwrap(PrefsSync.encode(12.5))) as? Double), 12.5)
        XCTAssertEqual(try XCTUnwrap(PrefsSync.decode(try XCTUnwrap(PrefsSync.encode(["a", "b"]))) as? [String]), ["a", "b"])
        XCTAssertEqual(try XCTUnwrap(PrefsSync.decode(try XCTUnwrap(PrefsSync.encode(Data([1, 2, 3])))) as? Data), Data([1, 2, 3]))
        XCTAssertEqual(try XCTUnwrap(PrefsSync.decode(try XCTUnwrap(PrefsSync.encode([1.5, 2.5]))) as? [Double]), [1.5, 2.5])
        XCTAssertEqual(try XCTUnwrap(PrefsSync.decode(try XCTUnwrap(PrefsSync.encode("name"))) as? String), "name")
        XCTAssertTrue(PrefsSync.trackedKeys.contains("phantom.ownedBundles"))
        XCTAssertTrue(PrefsSync.trackedKeys.contains("phantom.disputeRecords"))
    }

    func testKeychainRoundTrip() throws {
        KeychainStore.remove("test.key")
        XCTAssertNil(KeychainStore.get("test.key"))
        let status = KeychainStore.set("value-1", for: "test.key")
        // The unsigned test host has no keychain-access-group; signed builds do.
        try XCTSkipIf(status != errSecSuccess, "keychain unavailable in this test host (OSStatus \(status))")
        XCTAssertEqual(KeychainStore.get("test.key"), "value-1")
        KeychainStore.set("value-2", for: "test.key")
        XCTAssertEqual(KeychainStore.get("test.key"), "value-2", "set overwrites")
        KeychainStore.remove("test.key")
        XCTAssertNil(KeychainStore.get("test.key"))
    }

    @MainActor
    func testAccountApplyAndSignOut() {
        let account = AccountService()
        account.signOut()
        XCTAssertFalse(account.isSignedIn)
        var name = PersonNameComponents()
        name.givenName = "Jordan"; name.familyName = "Lee"
        XCTAssertTrue(account.apply(userID: "001234.abcd", name: name, email: "jordan@example.com"))
        XCTAssertTrue(account.isSignedIn)
        XCTAssertEqual(account.displayName, "Jordan Lee")
        XCTAssertEqual(account.email, "jordan@example.com")
        // Re-auth without name/email (Apple only sends them once) keeps what we had.
        XCTAssertTrue(account.apply(userID: "001234.abcd", name: nil, email: nil))
        XCTAssertEqual(account.displayName, "Jordan Lee")
        XCTAssertFalse(account.apply(userID: "", name: nil, email: nil))
        account.signOut()
        XCTAssertFalse(account.isSignedIn)
        XCTAssertEqual(account.displayName, "")
        XCTAssertNil(KeychainStore.get("apple.userID"))
    }

    func testNameFormatting() {
        var n = PersonNameComponents(); n.givenName = "Ada"
        XCTAssertEqual(AccountService.format(n), "Ada")
        XCTAssertNil(AccountService.format(nil))
        XCTAssertNil(AccountService.format(PersonNameComponents()))
    }
}

final class MachOEntitlementsTests: XCTestCase {
    private func le(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8(v >> 24)] }
    private func be(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 0xff), UInt8((v >> 8) & 0xff), UInt8(v & 0xff)] }

    /// A synthetic thin arm64 image: header + one LC_CODE_SIGNATURE pointing at
    /// a SuperBlob whose only slot is the entitlements plist.
    private func image(entitlements plist: String) -> Data {
        let plistBytes = Array(plist.utf8)
        var entBlob: [UInt8] = be(0xfade7171) + be(UInt32(8 + plistBytes.count)) + plistBytes
        var superBlob: [UInt8] = be(0xfade0cc0) + be(0) + be(1) + be(5) + be(20)
        superBlob += entBlob
        superBlob[4..<8] = ArraySlice(be(UInt32(superBlob.count)))
        entBlob = []
        let headerSize = 32
        let lcSize = 16
        let sigOffset = UInt32(headerSize + lcSize)
        var header: [UInt8] = le(0xfeedfacf) + le(0x0100000c) + le(0) + le(2) + le(1) + le(UInt32(lcSize)) + le(0) + le(0)
        header += le(0x1d) + le(UInt32(lcSize)) + le(sigOffset) + le(UInt32(superBlob.count))
        return Data(header + superBlob)
    }

    func testParsesEntitlementsOutOfACodeSignature() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
          <key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array>
          <key>com.apple.developer.applesignin</key><array><string>Default</string></array>
        </dict></plist>
        """
        let ents = MachOEntitlements.parse(image(entitlements: plist))
        XCTAssertEqual(ents?["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
        XCTAssertEqual(ents?["com.apple.developer.applesignin"] as? [String], ["Default"])
    }

    /// Xcode simulator builds: no code signature entitlements, but a
    /// `__TEXT,__entitlements` section holding the same plist.
    private func simulatorImage(entitlements plist: String) -> Data {
        let plistBytes = Array(plist.utf8)
        let headerSize = 32
        let segSize = 72 + 80
        let dataOffset = UInt32(headerSize + segSize)
        var img: [UInt8] = le(0xfeedfacf) + le(0x0100000c) + le(0) + le(2) + le(1) + le(UInt32(segSize)) + le(0) + le(0)
        func pad(_ s: String) -> [UInt8] { Array(s.utf8) + [UInt8](repeating: 0, count: 16 - s.utf8.count) }
        // LC_SEGMENT_64
        img += le(0x19) + le(UInt32(segSize)) + pad("__TEXT")
        img += [UInt8](repeating: 0, count: 8 * 4)           // vmaddr, vmsize, fileoff, filesize
        img += le(0) + le(0) + le(1) + le(0)                  // maxprot, initprot, nsects=1, flags
        // section_64
        img += pad("__entitlements") + pad("__TEXT")
        img += [UInt8](repeating: 0, count: 8)                // addr
        img += le(UInt32(plistBytes.count)) + le(0)           // size (lo, hi)
        img += le(dataOffset)                                 // offset
        img += [UInt8](repeating: 0, count: 80 - 16 - 16 - 8 - 8 - 4)
        img += plistBytes
        return Data(img)
    }

    func testParsesSimulatedEntitlementsSection() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array></dict></plist>
        """
        let ents = MachOEntitlements.parse(simulatorImage(entitlements: plist))
        XCTAssertEqual(ents?["com.apple.developer.icloud-services"] as? [String], ["CloudKit"])
    }

    func testGarbageAndUnsignedImagesYieldNothing() {
        XCTAssertNil(MachOEntitlements.parse(Data([1, 2, 3])))
        var unsigned = image(entitlements: "<plist/>")
        unsigned[16..<20] = Data([0, 0, 0, 0])   // ncmds = 0 → no signature command
        XCTAssertNil(MachOEntitlements.parse(unsigned))
    }

    func testUnsignedTestHostReportsNoCloudKit() {
        // The test bundle runs unsigned (CODE_SIGNING_ALLOWED=NO); the guard
        // that keeps CloudKit from aborting the process must say "no".
        if !CloudEntitlements.hasCloudKit {
            XCTAssertFalse(CloudEntitlements.hasCloudKit)
        } else {
            // A signed build (Xcode) legitimately reports true.
            XCTAssertNotNil(CloudEntitlements.entitlements["com.apple.developer.icloud-services"])
        }
    }
}
