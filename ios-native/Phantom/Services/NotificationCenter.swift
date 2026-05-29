import Foundation
import UserNotifications

/// Real local notifications via UNUserNotificationCenter.
/// We schedule:
///   - Trial-ending: 1 day before trialEndsAt
///   - Price hike: 7 days before hike effective date (alerts also live in the in-app feed)
///   - Zombie nudge: every 14 days if score ≥ 80 and not cancelled
enum NotificationService {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func currentAuthorization() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func scheduleTrialEnd(subscriptionId: String, name: String, trialEndsAt: Date) async {
        let triggerDate = trialEndsAt.addingTimeInterval(-86_400) // 1 day before
        guard triggerDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(name) trial ends tomorrow"
        content.body = "You'll be charged automatically unless you cancel today."
        content.sound = .default
        content.userInfo = ["route": "subscription", "id": subscriptionId]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(
            identifier: "trial-\(subscriptionId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(req)
    }

    static func schedulePriceHike(subscriptionId: String, name: String, from: Double, to: Double, effective: Date) async {
        let triggerDate = effective.addingTimeInterval(-7 * 86_400)
        guard triggerDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(name) is raising prices in 7 days"
        content.body = String(format: "$%.2f → $%.2f / month. Cancel or negotiate now.", from, to)
        content.sound = .default
        content.userInfo = ["route": "subscription", "id": subscriptionId]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(
            identifier: "hike-\(subscriptionId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(req)
    }

    static func scheduleZombieNudge(subscriptionId: String, name: String, score: Int) async {
        guard score >= 80 else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(name) is costing you money"
        content.body = "Zombie score \(score)/100. Tap to review."
        content.sound = .default
        content.userInfo = ["route": "subscription", "id": subscriptionId]
        // Fire 14 days from now, repeat every 14 days
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 14 * 86_400, repeats: true)
        let req = UNNotificationRequest(
            identifier: "zombie-\(subscriptionId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(req)
    }

    /// Verification reminder after the user says they cancelled at the vendor.
    /// Fires once, ~one billing cycle later, nudging them to re-scan their
    /// latest statement so Phantom can confirm the charge actually stopped.
    /// This is the honest version of "did it really go through?" — Phantom
    /// can't watch the vendor, but it can remind the user to check.
    static func scheduleCancellationCheck(subscriptionId: String, name: String, afterDays: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Did \(name) actually stop charging?"
        content.body = "Re-scan your latest statement in Phantom to confirm the cancellation went through. If it didn't, generate a dispute letter."
        content.sound = .default
        content.userInfo = ["route": "subscription", "id": subscriptionId]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(max(1, afterDays)) * 86_400, repeats: false)
        let req = UNNotificationRequest(
            identifier: "cancelcheck-\(subscriptionId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(req)
    }

    static func cancelCancellationCheck(for subscriptionId: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cancelcheck-\(subscriptionId)"])
    }

    /// Cancels the "nudge" notifications for a sub (trial / hike / zombie). Does
    /// NOT touch the cancellation verification reminder — that's managed
    /// independently via `cancelCancellationCheck` so marking a sub cancelled
    /// doesn't wipe the "did it really stop?" reminder.
    static func cancel(for subscriptionId: String) async {
        let ids = ["trial-\(subscriptionId)", "hike-\(subscriptionId)", "zombie-\(subscriptionId)"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
