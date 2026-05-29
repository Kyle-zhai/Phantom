import Foundation

/// Bridge between the app and the Home/Lock Screen widget. The widget runs in a
/// separate process and can only read the app's data through a shared App Group
/// container, so the app writes a small denormalized snapshot here on every data
/// change and the widget reads it.
///
/// IMPORTANT: the App Group id below must be enabled on BOTH targets in the
/// Apple Developer portal (Signing & Capabilities → App Groups) before an
/// App Store / device build. Simulator builds work without registration.
enum SharedStore {
    static let appGroup = "group.com.yinanzhai.phantom"
    private static let snapshotKey = "phantom.widget.snapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    struct Snapshot: Codable, Equatable {
        var monthlyTotal: Double
        var yearlyTotal: Double
        var activeCount: Int
        var zombieCount: Int
        var potentialYearlySavings: Double
        var realizedYearlySavings: Double
        var nextChargeName: String?
        var nextChargeAmount: Double?
        var nextChargeDate: Date?
        var updatedAt: Date

        static let placeholder = Snapshot(
            monthlyTotal: 84.97, yearlyTotal: 1019.64, activeCount: 9, zombieCount: 3,
            potentialYearlySavings: 287.88, realizedYearlySavings: 0,
            nextChargeName: "Netflix", nextChargeAmount: 22.99,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            updatedAt: Date()
        )

        static let empty = Snapshot(
            monthlyTotal: 0, yearlyTotal: 0, activeCount: 0, zombieCount: 0,
            potentialYearlySavings: 0, realizedYearlySavings: 0,
            nextChargeName: nil, nextChargeAmount: nil, nextChargeDate: nil,
            updatedAt: .distantPast
        )
    }

    static func save(_ snapshot: Snapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> Snapshot {
        guard let defaults,
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
