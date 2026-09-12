import XCTest
import CloudKit
import UIKit
@testable import Phantom

final class PickTests: XCTestCase {
    private func samplePick() -> AppPick {
        AppPick(id: "abc", name: "Fitbod", category: .fitness, tagline: "Lifting plans that adapt",
                details: "Generates workouts from what you have.", url: URL(string: "https://fitbod.me")!,
                appStoreURL: URL(string: "https://apps.apple.com/us/app/id1234"), clicks: 12, status: .approved,
                submitterToken: "tok", createdAt: Date(), reports: 0)
    }

    func testRecordRoundTripKeepsEverythingButTheCount() {
        let pick = samplePick()
        let record = CKRecord(recordType: AppPick.recordType, recordID: pick.recordID)
        pick.apply(to: record)
        XCTAssertNil(record["clicks"], "opens live on PickCounter, never on the pick itself")
        let back = AppPick(record: record)
        XCTAssertEqual(back?.id, "abc")
        XCTAssertEqual(back?.name, "Fitbod")
        XCTAssertEqual(back?.category, .fitness)
        XCTAssertEqual(back?.tagline, pick.tagline)
        XCTAssertEqual(back?.url, pick.url)
        XCTAssertEqual(back?.appStoreURL, pick.appStoreURL)
        XCTAssertEqual(back?.status, .approved)
        XCTAssertEqual(back?.submitterToken, "tok")
        XCTAssertEqual(back?.clicks, 0)
        XCTAssertEqual(pick.counterRecordID.recordName, "counter-abc")
        XCTAssertNil(AppPick(record: CKRecord(recordType: "Other")), "wrong type is rejected")
    }

    func testValidation() {
        var f = PickSubmission()
        XCTAssertThrowsError(try f.validate()) { XCTAssertEqual($0 as? PickSubmission.ValidationError, .name) }
        f.name = "Fitbod"
        XCTAssertThrowsError(try f.validate()) { XCTAssertEqual($0 as? PickSubmission.ValidationError, .tagline) }
        f.tagline = String(repeating: "x", count: 81)
        XCTAssertThrowsError(try f.validate()) { XCTAssertEqual($0 as? PickSubmission.ValidationError, .tagline) }
        f.tagline = "Lifting plans"
        f.urlText = "not a url"
        XCTAssertThrowsError(try f.validate()) { XCTAssertEqual($0 as? PickSubmission.ValidationError, .url) }
        f.urlText = "fitbod.me"
        f.appStoreText = "https://google.com"
        XCTAssertThrowsError(try f.validate()) { XCTAssertEqual($0 as? PickSubmission.ValidationError, .appStoreURL) }
        f.appStoreText = "https://apps.apple.com/us/app/id1"
        XCTAssertThrowsError(try f.validate()) { XCTAssertEqual($0 as? PickSubmission.ValidationError, .screenshot) }
        f.screenshot = Data([1, 2, 3])
        let v = try? f.validate()
        XCTAssertEqual(v?.url.absoluteString, "https://fitbod.me")
        XCTAssertEqual(v?.appStoreURL?.host, "apps.apple.com")
    }

    func testURLNormalization() {
        XCTAssertEqual(PickSubmission.normalizeURL("example.com/app")?.absoluteString, "https://example.com/app")
        XCTAssertEqual(PickSubmission.normalizeURL("HTTP://Example.com")?.absoluteString, "http://example.com")
        XCTAssertNil(PickSubmission.normalizeURL("localhost"))
        XCTAssertNil(PickSubmission.normalizeURL("two words.com"))
        XCTAssertNil(PickSubmission.normalizeURL(""))
    }

    func testRankingByOpensThenAge() {
        let old = Date().addingTimeInterval(-86_400)
        var a = samplePick(); a = AppPick(id: "a", name: "A", category: .other, tagline: "", details: "", url: a.url, appStoreURL: nil, clicks: 5, status: .approved, submitterToken: "", createdAt: Date(), reports: 0)
        let b = AppPick(id: "b", name: "B", category: .other, tagline: "", details: "", url: a.url, appStoreURL: nil, clicks: 9, status: .approved, submitterToken: "", createdAt: Date(), reports: 0)
        let c = AppPick(id: "c", name: "C", category: .other, tagline: "", details: "", url: a.url, appStoreURL: nil, clicks: 5, status: .approved, submitterToken: "", createdAt: old, reports: 0)
        XCTAssertEqual(PickRanking.ranked([a, b, c]).map(\.id), ["b", "c", "a"])
    }

    func testClickKeyIsOnePerPersonPerAppPerDay() {
        var comps = DateComponents(); comps.year = 2026; comps.month = 9; comps.day = 10; comps.hour = 23
        let cal = Calendar(identifier: .gregorian)
        let d = cal.date(from: comps)!
        let key = PickClickKey.key(pickID: "abc", userToken: "tok", day: d)
        XCTAssertTrue(key.hasPrefix("abc|tok|2026"))
        let token = PickClickKey.token(fromUserRecordName: "_a1b2c3")
        XCTAssertEqual(token.count, 24)
        XCTAssertEqual(token, PickClickKey.token(fromUserRecordName: "_a1b2c3"), "deterministic")
        XCTAssertNotEqual(token, PickClickKey.token(fromUserRecordName: "_other"))
    }

    func testScreenshotIsDownscaledAndCompressed() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 3000)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 3000))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 100, y: 100, width: 1500, height: 900))
        }
        let data = try XCTUnwrap(big.pngData())
        let prepared = try XCTUnwrap(PickScreenshot.prepare(data))
        let out = try XCTUnwrap(UIImage(data: prepared))
        XCTAssertLessThanOrEqual(max(out.size.width, out.size.height), PickScreenshot.maxDimension + 1)
        XCTAssertLessThanOrEqual(prepared.count, PickScreenshot.maxBytes)
    }
}
