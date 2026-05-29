import WidgetKit
import SwiftUI

// The widget reads the denormalized snapshot the app writes to the shared App
// Group container (see SharedStore). It never touches SwiftData directly —
// widgets run in a separate, sandboxed process.

struct PhantomEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedStore.Snapshot
}

struct PhantomProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhantomEntry {
        PhantomEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PhantomEntry) -> Void) {
        let snap = context.isPreview ? .placeholder : SharedStore.load()
        completion(PhantomEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhantomEntry>) -> Void) {
        let snap = SharedStore.load()
        // Refresh periodically so "next charge in N days" stays current even if
        // the user doesn't open the app. The app also force-reloads on changes.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [PhantomEntry(date: Date(), snapshot: snap)], policy: .after(next)))
    }
}

private func money(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.locale = Locale(identifier: "en_US")
    f.maximumFractionDigits = v >= 100 ? 0 : 2
    f.minimumFractionDigits = v >= 100 ? 0 : 2
    return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
}

private func daysUntil(_ date: Date?) -> Int? {
    guard let date else { return nil }
    let cal = Calendar.current
    return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day
}

private func nextChargeText(_ s: SharedStore.Snapshot) -> String? {
    guard let name = s.nextChargeName, let amt = s.nextChargeAmount else { return nil }
    guard let d = daysUntil(s.nextChargeDate) else { return "\(name) \(money(amt))" }
    let when = d <= 0 ? "today" : (d == 1 ? "tomorrow" : "in \(d)d")
    return "\(name) \(money(amt)) \(when)"
}

struct PhantomWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhantomEntry
    private var s: SharedStore.Snapshot { entry.snapshot }
    private var isEmpty: Bool { s.activeCount == 0 }

    var body: some View {
        switch family {
        case .systemMedium:         medium.containerBackground(.black, for: .widget)
        case .accessoryRectangular: rect.containerBackground(.clear, for: .widget)
        case .accessoryInline:      inline.containerBackground(.clear, for: .widget)
        default:                    small.containerBackground(.black, for: .widget)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEmpty {
                emptyPrompt
            } else {
                Text("EVERY MONTH").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                Text(money(s.monthlyTotal))
                    .font(.system(size: 30, weight: .black)).foregroundStyle(.white)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Spacer(minLength: 6)
                if s.zombieCount > 0 {
                    Label("\(s.zombieCount) zombie\(s.zombieCount == 1 ? "" : "s")", systemImage: "moon.zzz.fill")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
                }
                if let next = nextChargeText(s) {
                    Text(next).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("EVERY MONTH").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                Text(money(s.monthlyTotal))
                    .font(.system(size: 34, weight: .black)).foregroundStyle(.white)
                    .minimumScaleFactor(0.6).lineLimit(1)
                if s.yearlyTotal > 0 {
                    Text("\(money(s.yearlyTotal))/yr").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if isEmpty {
                    emptyPrompt
                } else {
                    metric(value: "\(s.zombieCount)", label: "zombies", tint: s.zombieCount > 0 ? .red : .white)
                    if s.potentialYearlySavings > 0 {
                        metric(value: money(s.potentialYearlySavings), label: "to save / yr", tint: .green)
                    }
                    if let next = nextChargeText(s) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NEXT CHARGE").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                            Text(next).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func metric(value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(value).font(.system(size: 18, weight: .black)).foregroundStyle(tint)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var emptyPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            Text("Scan your subscriptions").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            Text("Open Phantom to start").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private var rect: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Phantom").font(.system(size: 12, weight: .bold))
            if isEmpty {
                Text("Scan your subscriptions").font(.system(size: 13, weight: .semibold))
            } else {
                Text("\(money(s.monthlyTotal))/mo · \(s.zombieCount) zombie\(s.zombieCount == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let next = nextChargeText(s) {
                    Text(next).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text(isEmpty ? "Phantom · scan your subs" : "\(money(s.monthlyTotal))/mo · \(s.zombieCount) zombies")
    }
}

struct PhantomWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhantomWidget", provider: PhantomProvider()) { entry in
            PhantomWidgetView(entry: entry)
        }
        .configurationDisplayName("Phantom")
        .description("Monthly subscription spend, zombie count, and your next charge.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PhantomWidgetBundle: WidgetBundle {
    var body: some Widget {
        PhantomWidget()
    }
}
