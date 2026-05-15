import SwiftUI

/// Type-in fallback when OCR isn't ideal or the user knows exactly what to add.
struct ManualAddSubscriptionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var cycle: BillingCycle = .monthly
    @State private var category: Category = .entertainment
    @State private var nextBillingOffset: Int = 30

    private var amount: Double { Double(amountText) ?? 0 }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                Text("Add a subscription")
                    .font(AppFont.h1).foregroundStyle(Palette.ink)
                    .padding(.top, 18)
                Text("Anything you pay for on a schedule. Edit any field later.")
                    .font(AppFont.body).foregroundStyle(Palette.mute).padding(.top, 6)

                field(label: "Name", text: $name, placeholder: "e.g. Netflix")
                field(label: "Price", text: $amountText, placeholder: "e.g. 22.99", keyboard: .decimalPad, prefix: "$")

                pickerRow(label: "Billing cycle") {
                    Picker("", selection: $cycle) {
                        Text("Monthly").tag(BillingCycle.monthly)
                        Text("Yearly").tag(BillingCycle.yearly)
                        Text("Weekly").tag(BillingCycle.weekly)
                    }
                    .pickerStyle(.segmented)
                }

                pickerRow(label: "Category") {
                    Picker("", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.menu).tint(Palette.ink)
                }

                pickerRow(label: "Next billing") {
                    Picker("", selection: $nextBillingOffset) {
                        Text("Today").tag(0)
                        Text("In 7 days").tag(7)
                        Text("In 14 days").tag(14)
                        Text("In 30 days").tag(30)
                    }
                    .pickerStyle(.segmented)
                }

                PrimaryButton("Add to Phantom") { commit() }
                    .disabled(!valid)
                    .opacity(valid ? 1 : 0.4)
                    .padding(.top, 28)

                PrimaryButton("Cancel", variant: .ghost) { dismiss() }
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Palette.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .background(Palette.surface, in: Circle())
            }
            Spacer()
            Text("ADD MANUALLY").font(AppFont.smallB).foregroundStyle(Palette.mute)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 4)
    }

    private func field(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default, prefix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute)
            HStack(spacing: 6) {
                if let prefix { Text(prefix).font(AppFont.body).foregroundStyle(Palette.mute) }
                TextField(placeholder, text: text)
                    .font(AppFont.body)
                    .foregroundStyle(Palette.ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.white, in: RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Palette.border, lineWidth: 1))
        }
        .padding(.top, 16)
    }

    private func pickerRow<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(AppFont.smallB).foregroundStyle(Palette.mute)
            content()
        }
        .padding(.top, 16)
    }

    private func commit() {
        let normalized = name.trimmingCharacters(in: .whitespaces)
        let id = normalized.lowercased().replacingOccurrences(of: " ", with: "-")
        let next = Date().addingTimeInterval(TimeInterval(nextBillingOffset * 86_400))
        let sub = Subscription(
            id: id,
            name: normalized,
            vendor: normalized,
            brandHex: "111111",
            category: category,
            amount: amount,
            cycle: cycle,
            nextBilling: next,
            startedAt: Date(),
            lastUsedAt: nil,
            sessionsLast30d: 0,
            userRating: nil,
            marketAverage: amount,
            trialEndsAt: nil,
            hasPriceHike: nil,
            hasOverlapWith: [],
            notes: "Added manually."
        )
        store.mergeImported(subs: [sub], transactions: [])
        dismiss()
    }
}
