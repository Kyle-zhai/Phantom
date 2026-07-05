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
        // Fire ~14 days out at an ABSOLUTE date. The caller only (re)schedules
        // this when one isn't already pending, so the countdown is no longer
        // reset to zero on every launch/reschedule — which previously meant it
        // never fired for any regularly-active user. Once it fires it drops out
        // of pending and the next reschedule re-arms it ~14 days later.
        let fireAt = Date().addingTimeInterval(14 * 86_400)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
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
    static func scheduleCancellationCheck(subscriptionId: String, name: String, fireAt: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Did \(name) actually stop charging?"
        content.body = "Re-scan your latest statement in Phantom to confirm the cancellation went through. If it didn't, generate a dispute letter."
        content.sound = .default
        content.userInfo = ["route": "subscription", "id": subscriptionId]
        // Anchor to the ABSOLUTE target date so re-adding on a later reschedule
        // lands on the same wall-clock time instead of sliding forward. If the
        // target already passed, fire once shortly (don't perpetually re-push).
        let trigger: UNNotificationTrigger
        if fireAt > Date() {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        }
        let req = UNNotificationRequest(
            identifier: "cancelcheck-\(subscriptionId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(req)
    }

    /// Re-engagement nudge for users who imported but never rated a sub — the
    /// rating is the strongest signal the zombie score has on-device, so this
    /// pulls them back to the moment of value. Absolute-date so a reschedule
    /// doesn't reset it; the scheduler drops it once anything is rated.
    static func scheduleRatingNudge(fireInDays: Int = 3) async {
        let content = UNMutableNotificationContent()
        content.title = "Which subscriptions do you actually use?"
        content.body = "Rate them in Phantom — 2 taps each — to reveal your zombie subscriptions and what you can cut."
        content.sound = .default
        content.userInfo = ["route": "radar"]
        let fireAt = Date().addingTimeInterval(Double(max(1, fireInDays)) * 86_400)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: "ratenudge", content: content, trigger: trigger)
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

    /// Identifiers of everything currently scheduled — lets the scheduler
    /// reconcile (add missing / remove stale) instead of wiping and re-adding,
    /// which would reset relative-countdown triggers on every launch.
    static func pendingIdentifiers() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map { $0.identifier })
    }

    static func remove(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
